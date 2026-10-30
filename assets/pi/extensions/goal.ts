/**
 * /goal: objetivo de sesion con auto-continuacion acotada.
 *
 * Portado del `/goal` de opencode/Codex (objetivo persistente + continuacion
 * automatica hasta completar o agotar presupuesto). Pi ya da el primitivo:
 * `agent_before_settle` puede devolver `continue: true`. El trabajo real es
 * decidir CUANDO continuar, porque sin techos esto es una factura abierta y la
 * doc de pi lo dice explicito: "guard continuation conditions because an
 * unconditional continuation can loop".
 *
 * El estado vive en la rama de la sesion (`pi.appendEntry`), no en memoria: se
 * relee del branch en cada decision, asi un reload o una rama restaurada nunca
 * mienten.
 *
 * La logica de decision es pura y se prueba con `node assets/pi/goal.check.mjs`.
 */
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

/** Tipo del entry de sesion que guarda el estado. */
export const GOAL_ENTRY = "goal";
/** Continuaciones permitidas si no se pasa `--budget`. */
export const DEFAULT_BUDGET = 6;
/** Marcador con el que el modelo declara que no puede avanzar. */
export const BLOCKED_MARKER = "GOAL BLOCKED:";

export type GoalStatus = "active" | "paused" | "blocked" | "complete";

export interface GoalState {
	objective: string;
	status: GoalStatus;
	budget: number;
	used: number;
	reason?: string;
	updatedAt: number;
}

/** Lo que el runtime sabe del turno que acaba de terminar. */
export interface SettleView {
	outcome: "completed" | "aborted" | "error";
	toolCallsThisRun: number;
	hasPendingMessages: boolean;
	blocked: string | null;
}

export type Decision =
	| { action: "continue"; next: GoalState; prompt: string; reason: string }
	| { action: "stop"; next: GoalState | null; reason: string };

const stop = (next: GoalState | null, reason: string): Decision => ({ action: "stop", next, reason });

const closed = (state: GoalState, status: GoalStatus, reason: string, now: number): GoalState => ({
	...state,
	status,
	reason,
	updatedAt: now,
});

/**
 * Decide si hay que forzar otro turno. Ante la duda siempre para: cada rama
 * insegura del `if` deja el goal quieto en vez de gastar un turno mas.
 */
export function decide(state: GoalState, view: SettleView, now: number): Decision {
	if (state.status !== "active") return stop(null, `goal ${state.status}`);
	if (view.outcome !== "completed") return stop(null, `run ended: ${view.outcome}`);
	if (view.hasPendingMessages) return stop(null, "user message pending");
	if (view.blocked) return stop(closed(state, "blocked", view.blocked, now), "blocked marker");
	if (state.used >= state.budget) {
		return stop(closed(state, "blocked", `budget ${state.used}/${state.budget} spent`, now), "budget spent");
	}
	if (view.toolCallsThisRun === 0) {
		return stop(closed(state, "paused", "no tool calls in this run", now), "no progress");
	}
	const next: GoalState = { ...state, used: state.used + 1, updatedAt: now };
	return { action: "continue", next, reason: "progress", prompt: continuationPrompt(next) };
}

/** Mensaje que entra al contexto para empujar el turno siguiente. */
export function continuationPrompt(state: GoalState): string {
	return (
		`[goal ${state.used}/${state.budget}] ${state.objective}\n` +
		`Segui con el proximo paso verificable, sin repetir lo ya hecho. ` +
		`Si no podes avanzar, responde exactamente "${BLOCKED_MARKER} <razon>".`
	);
}

export type ParsedGoal = { objective: string; budget: number } | { error: string };

/** `null` significa "sin objetivo": mostrar el estado actual. */
export function parseGoalArgs(raw: string): ParsedGoal | null {
	const tokens = raw.trim().split(/\s+/).filter(Boolean);
	if (tokens.length === 0) return null;
	let budget = DEFAULT_BUDGET;
	const rest: string[] = [];
	for (let i = 0; i < tokens.length; i++) {
		if (tokens[i] !== "--budget") {
			rest.push(tokens[i] as string);
			continue;
		}
		const value = Number(tokens[i + 1]);
		if (!Number.isInteger(value) || value < 1 || value > 50) return { error: "--budget necesita un entero entre 1 y 50" };
		budget = value;
		i++;
	}
	const objective = rest.join(" ").trim();
	if (!objective) return { error: "falta el objetivo" };
	return { objective, budget };
}

/** Texto plano de un mensaje del agente, para buscar el marcador. */
export function messageText(message: unknown): string {
	if (!message || typeof message !== "object") return "";
	const content = (message as { content?: unknown }).content;
	if (typeof content === "string") return content;
	if (!Array.isArray(content)) return "";
	const parts: string[] = [];
	for (const block of content) {
		if (!block || typeof block !== "object") continue;
		const candidate = block as { type?: unknown; text?: unknown };
		if (candidate.type === "text" && typeof candidate.text === "string") parts.push(candidate.text);
	}
	return parts.join("\n");
}

export function detectBlocked(text: string): string | null {
	const at = text.indexOf(BLOCKED_MARKER);
	if (at < 0) return null;
	const reason = (text.slice(at + BLOCKED_MARKER.length).split("\n")[0] ?? "").trim();
	return reason || "sin razon declarada";
}

function normalize(data: unknown): GoalState | null {
	if (!data || typeof data !== "object") return null;
	const raw = data as Partial<GoalState>;
	if (typeof raw.objective !== "string" || !raw.objective) return null;
	const status: GoalStatus =
		raw.status === "active" || raw.status === "paused" || raw.status === "blocked" || raw.status === "complete"
			? raw.status
			: "paused";
	const budget = Number.isInteger(raw.budget) && (raw.budget as number) > 0 ? (raw.budget as number) : DEFAULT_BUDGET;
	const used = Number.isInteger(raw.used) && (raw.used as number) >= 0 ? (raw.used as number) : 0;
	return {
		objective: raw.objective,
		status,
		budget,
		used,
		...(typeof raw.reason === "string" ? { reason: raw.reason } : {}),
		updatedAt: typeof raw.updatedAt === "number" ? raw.updatedAt : 0,
	};
}

function describe(state: GoalState | null): string {
	if (!state) return "sin goal";
	const tail = state.reason ? ` - ${state.reason}` : "";
	return `${state.status} ${state.used}/${state.budget}: ${state.objective}${tail}`;
}

export default function goalExtension(pi: ExtensionAPI): void {
	// Datos del ultimo turno, que solo llegan por eventos. El estado del goal no
	// se cachea: se lee de la rama en cada decision.
	let toolCallsThisRun = 0;
	let lastBlocked: string | null = null;

	const read = (ctx: ExtensionContext): GoalState | null => {
		const branch = ctx.sessionManager.getBranch();
		for (let i = branch.length - 1; i >= 0; i--) {
			const entry = branch[i] as { type?: unknown; customType?: unknown; data?: unknown } | undefined;
			if (entry?.type === "custom" && entry.customType === GOAL_ENTRY) return normalize(entry.data);
		}
		return null;
	};

	const save = (state: GoalState): void => {
		pi.appendEntry<GoalState>(GOAL_ENTRY, state);
	};

	pi.on("session_start", () => {
		toolCallsThisRun = 0;
		lastBlocked = null;
	});

	// El ultimo turno de un run normal NO usa herramientas (es la respuesta de
	// cierre), asi que medir solo ese turno daria "sin progreso" siempre. Se
	// acumula el run entero y se resetea cuando arranca el siguiente.
	pi.on("agent_start", () => {
		toolCallsThisRun = 0;
	});

	pi.on("turn_end", (event) => {
		toolCallsThisRun += event.toolResults.length;
		lastBlocked = detectBlocked(messageText(event.message));
	});

	pi.on("agent_before_settle", (event, ctx) => {
		const state = read(ctx);
		if (!state) return;
		const decision = decide(
			state,
			{
				outcome: event.outcome,
				toolCallsThisRun,
				hasPendingMessages: ctx.hasPendingMessages(),
				blocked: lastBlocked,
			},
			Date.now(),
		);
		lastBlocked = null;
		// El estado va en `entries`, no en pi.appendEntry: este hook es un boundary
		// transaccional y un append directo se pierde (verificado en RPC: la
		// continuacion corria pero el estado final nunca quedaba escrito).
		const entry = (next: GoalState) => ({ type: "custom" as const, customType: GOAL_ENTRY, data: next });
		if (decision.action === "stop") return decision.next ? { entries: [entry(decision.next)] } : undefined;
		return {
			continue: true,
			entries: [
				entry(decision.next),
				{ type: "custom_message" as const, customType: GOAL_ENTRY, content: decision.prompt, display: true },
			],
		};
	});

	pi.registerCommand("goal", {
		description: "Objetivo de sesion con auto-continuacion acotada (/goal <objetivo> [--budget N])",
		handler: async (args, ctx) => {
			const raw = args.trim();
			const current = read(ctx);
			const now = Date.now();

			if (raw === "clear" || raw === "stop") {
				if (!current) return ctx.ui.notify("sin goal activo", "info");
				save(closed(current, "complete", "cleared", now));
				return ctx.ui.notify("goal cerrado", "info");
			}
			if (raw === "pause") {
				if (!current || current.status !== "active") return ctx.ui.notify("no hay goal activo", "info");
				save(closed(current, "paused", "paused by user", now));
				return ctx.ui.notify("goal en pausa", "info");
			}
			if (raw === "resume") {
				if (!current || current.status === "active") return ctx.ui.notify("nada que reanudar", "info");
				save({ ...current, status: "active", reason: undefined, updatedAt: now });
				return ctx.ui.notify(`goal reanudado (${current.used}/${current.budget})`, "info");
			}

			const parsed = parseGoalArgs(raw);
			if (parsed === null) return ctx.ui.notify(describe(current), "info");
			if ("error" in parsed) return ctx.ui.notify(parsed.error, "error");
			const next: GoalState = {
				objective: parsed.objective,
				status: "active",
				budget: parsed.budget,
				used: 0,
				updatedAt: now,
			};
			save(next);
			ctx.ui.notify(`goal activo, presupuesto ${parsed.budget} continuaciones: ${parsed.objective}`, "info");
		},
	});
}
