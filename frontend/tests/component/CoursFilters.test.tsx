import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";
import CoursFilters from "@/components/CoursFilters";

function afficher(props: Partial<Parameters<typeof CoursFilters>[0]> = {}) {
  const onQueryChange = vi.fn();
  const onLevelChange = vi.fn();
  render(
    <CoursFilters query="" level="tous" onQueryChange={onQueryChange} onLevelChange={onLevelChange} {...props} />,
  );
  return { onQueryChange, onLevelChange };
}

describe("CoursFilters", () => {
  it("affiche les valeurs reçues", () => {
    afficher({ query: "git", level: "avance" });
    expect(screen.getByRole("searchbox", { name: "Rechercher un cours" })).toHaveValue("git");
    expect(screen.getByRole("combobox", { name: "Niveau" })).toHaveValue("avance");
  });

  it("propose « Tous les niveaux » puis les trois niveaux", () => {
    afficher();
    const options = screen.getAllByRole("option").map((o) => o.textContent);
    expect(options).toEqual(["Tous les niveaux", "Débutant", "Intermédiaire", "Avancé"]);
  });

  it("transmet la saisie de l'utilisateur", async () => {
    const user = userEvent.setup();
    const { onQueryChange } = afficher();
    await user.type(screen.getByRole("searchbox", { name: "Rechercher un cours" }), "d");
    expect(onQueryChange).toHaveBeenCalledWith("d");
  });

  it("transmet le niveau choisi", async () => {
    const user = userEvent.setup();
    const { onLevelChange } = afficher();
    await user.selectOptions(screen.getByRole("combobox", { name: "Niveau" }), "avance");
    expect(onLevelChange).toHaveBeenCalledWith("avance");
  });
});
