import { fileURLToPath } from "node:url";
import react from "@vitejs/plugin-react";
import { defineConfig } from "vitest/config";

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: { "@": fileURLToPath(new URL("./", import.meta.url)) },
  },
  test: {
    environment: "jsdom",
    setupFiles: ["./tests/setup.ts"],
    include: ["tests/{unit,component,integration}/**/*.test.{ts,tsx}"],
    coverage: {
      provider: "v8",
      include: ["lib/**/*.ts", "components/**/*.tsx"],
      // api.ts : testé en intégration ; CoursList et DevOpsLoop : couverts par les tests E2E
      exclude: ["lib/api.ts", "components/CoursList.tsx", "components/DevOpsLoop.tsx"],
      reporter: ["text", "html", "lcov"],
      reportsDirectory: "coverage",
      // Produit le rapport même si un test échoue (utile pour la partie 2 et pour SonarQube)
      reportOnFailure: true,
    },
  },
});
