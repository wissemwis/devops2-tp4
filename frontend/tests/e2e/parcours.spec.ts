import { expect, test } from "@playwright/test";

test.describe("Parcours d'un visiteur", () => {
  test("l'accueil liste les 6 cours dans l'ordre des séances", async ({ page }) => {
    await page.goto("/");
    const titres = page.getByRole("list", { name: "Liste des cours" }).getByRole("heading", { level: 3 });
    await expect(titres).toHaveCount(6);
    await expect(titres.first()).toHaveText("Introduction au DevOps");
    await expect(titres.last()).toHaveText("Intégration et déploiement continus");
  });

  test("la recherche « docker » réduit la liste", async ({ page }) => {
    await page.goto("/");
    await page.getByRole("searchbox", { name: "Rechercher un cours" }).fill("docker");
    await expect(page.getByRole("list", { name: "Liste des cours" }).getByRole("heading", { level: 3 })).toHaveCount(2);
    await expect(page.getByText("2 cours", { exact: true })).toBeVisible();
  });

  test("le filtre de niveau n'affiche que les cours avancés", async ({ page }) => {
    await page.goto("/");
    await page.getByRole("combobox", { name: "Niveau" }).selectOption("avance");
    const titres = page.getByRole("list", { name: "Liste des cours" }).getByRole("heading", { level: 3 });
    await expect(titres).toHaveCount(1);
    await expect(titres).toHaveText("Intégration et déploiement continus");
  });

  test("la fiche du cours d'introduction affiche sa durée", async ({ page }) => {
    await page.goto("/");
    await page.getByRole("link", { name: "Introduction au DevOps" }).click();
    await expect(page).toHaveURL(/\/cours\//);
    await expect(page.getByRole("heading", { level: 1 })).toHaveText("Introduction au DevOps");
    await expect(page.getByRole("main").getByText("1 h", { exact: true })).toBeVisible();
  });
});
