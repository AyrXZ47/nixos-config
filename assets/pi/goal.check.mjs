// Check runnable de la logica de /goal. Sin framework: node >= 22.6 lo corre
// directo (`node assets/pi/goal.check.mjs`) y falla con exit 1 al primer assert.
import assert from "node:assert/strict";
import {
	BLOCKED_MARKER,
	DEFAULT_BUDGET,
	continuationPrompt,
	decide,
	detectBlocked,
	parseGoalArgs,
} from "./extensions/goal.ts";

const NOW = 1_700_000_000_000;
const goal = (over = {}) => ({
	objective: "hacer pasar nix flake check",
	status: "active",
	budget: 3,
	used: 0,
	updatedAt: NOW,
	...over,
});
const view = (over = {}) => ({
	outcome: "completed",
	toolCallsThisRun: 2,
	hasPendingMessages: false,
	blocked: null,
	...over,
});

const cases = [];
const test = (name, fn) => cases.push([name, fn]);

test("goal inactivo no fuerza turnos", () => {
	const d = decide(goal({ status: "paused" }), view(), NOW);
	assert.equal(d.action, "stop");
	assert.equal(d.next, null); // no reescribe estado ajeno
});

test("abort o error no continuan", () => {
	for (const outcome of ["aborted", "error"]) {
		assert.equal(decide(goal(), view({ outcome }), NOW).action, "stop");
	}
});

test("un mensaje del humano pendiente gana sobre la continuacion", () => {
	assert.equal(decide(goal(), view({ hasPendingMessages: true }), NOW).action, "stop");
});

// `event.context.canContinue` llega en false justo cuando el turno termino normal
// (ultimo mensaje = assistant, ver core/agent-session.js en pi). La continuacion
// la habilita el custom_message que devuelve el hook, no un permiso previo: por eso
// decide() no lo consulta. Este caso fija el contrato.
test("un turno normal completado es continuable: canContinue no es precondicion", () => {
	const d = decide(goal(), view(), NOW);
	assert.equal(d.action, "continue");
	assert.equal(d.next.status, "active");
});

test("marcador de bloqueo cierra el goal con la razon", () => {
	const d = decide(goal(), view({ blocked: "falta disco" }), NOW);
	assert.equal(d.action, "stop");
	assert.equal(d.next.status, "blocked");
	assert.equal(d.next.reason, "falta disco");
});

test("presupuesto agotado: borde exacto en used === budget", () => {
	const last = decide(goal({ used: 2, budget: 3 }), view(), NOW);
	assert.equal(last.action, "continue");
	assert.equal(last.next.used, 3);

	const spent = decide(goal({ used: 3, budget: 3 }), view(), NOW);
	assert.equal(spent.action, "stop");
	assert.equal(spent.next.status, "blocked");
	assert.match(spent.next.reason, /budget 3\/3/);
});

test("turno sin herramientas no continua (anti loop de prosa)", () => {
	const d = decide(goal(), view({ toolCallsThisRun: 0 }), NOW);
	assert.equal(d.action, "stop");
	assert.equal(d.next.status, "paused");
	assert.match(d.next.reason, /no tool calls/);
});

test("camino feliz: continua, suma uso y empuja al modelo", () => {
	const d = decide(goal({ used: 1 }), view(), NOW);
	assert.equal(d.action, "continue");
	assert.equal(d.next.used, 2);
	assert.equal(d.next.status, "active");
	assert.ok(d.prompt.includes("hacer pasar nix flake check"), "el prompt lleva el objetivo");
	assert.ok(d.prompt.includes(BLOCKED_MARKER), "el prompt ensena el marcador que el hook detecta");
	assert.ok(d.prompt.includes("2/3"), "el prompt dice el presupuesto restante");
});

test("el prompt emitido corresponde al estado persistido, no al previo", () => {
	const d = decide(goal({ used: 1 }), view(), NOW);
	assert.equal(d.prompt, continuationPrompt(d.next));
});

test("parseGoalArgs: sin argumentos muestra estado", () => {
	assert.equal(parseGoalArgs(""), null);
	assert.equal(parseGoalArgs("   "), null);
});

test("parseGoalArgs: objetivo con presupuesto por defecto", () => {
	assert.deepEqual(parseGoalArgs("arreglar el build"), { objective: "arreglar el build", budget: DEFAULT_BUDGET });
});

test("parseGoalArgs: --budget explicito en cualquier posicion", () => {
	assert.deepEqual(parseGoalArgs("--budget 3 arreglar el build"), { objective: "arreglar el build", budget: 3 });
	assert.deepEqual(parseGoalArgs("arreglar el build --budget 12"), { objective: "arreglar el build", budget: 12 });
});

test("parseGoalArgs: presupuesto invalido o faltante no crea goal", () => {
	for (const raw of ["x --budget 0", "x --budget 51", "x --budget", "x --budget dos", "--budget 3"]) {
		assert.ok("error" in parseGoalArgs(raw), `deberia rechazar: ${raw}`);
	}
});

test("detectBlocked: solo el marcador, con razon o sin ella", () => {
	assert.equal(detectBlocked("todo bien, sigo"), null);
	assert.equal(detectBlocked(`${BLOCKED_MARKER} falta credencial\nmas texto`), "falta credencial");
	assert.equal(detectBlocked(`${BLOCKED_MARKER}`), "sin razon declarada");
});

let failed = 0;
for (const [name, fn] of cases) {
	try {
		fn();
		console.log(`ok   ${name}`);
	} catch (error) {
		failed++;
		console.error(`FAIL ${name}\n     ${error.message}`);
	}
}
console.log(`\n${cases.length - failed}/${cases.length} casos`);
process.exit(failed === 0 ? 0 : 1);
