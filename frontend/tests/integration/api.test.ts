// @vitest-environment node
import { describe, expect, it } from "vitest";
import { getCours, getCoursById } from "@/lib/api";

describe("API Strapi /api/courses (intégration)", () => {
  it("renvoie les 6 cours du seed avec les champs attendus", async () => {
    const cours = await getCours();
    expect(cours).toHaveLength(6);
    for (const c of cours) {
      expect(c).toEqual(
        expect.objectContaining({
          documentId: expect.any(String),
          title: expect.any(String),
          session: expect.any(Number),
          duration: expect.any(Number),
          level: expect.stringMatching(/^(debutant|intermediaire|avance)$/),
          topics: expect.any(Array),
        }),
      );
    }
  });

  it("renvoie les cours triés par séance", async () => {
    const cours = await getCours();
    expect(cours.map((c) => c.session)).toEqual([1, 2, 3, 4, 5, 6]);
  });

  it("renvoie la fiche d'un cours à partir de son identifiant", async () => {
    const [premier] = await getCours();
    const fiche = await getCoursById(premier.documentId);
    expect(fiche?.title).toBe(premier.title);
  });

  it("renvoie null pour un identifiant inexistant", async () => {
    expect(await getCoursById("inexistant")).toBeNull();
  });
});
