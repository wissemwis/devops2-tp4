'use strict';

const COURS = require('./seed/cours.json');

const PUBLIC_ACTIONS = ['api::course.course.find', 'api::course.course.findOne'];

// Donne au rôle Public le droit de lire les cours (sinon l'API répond 403)
async function openPublicAccess(strapi) {
  const publicRole = await strapi.db
    .query('plugin::users-permissions.role')
    .findOne({ where: { type: 'public' } });

  for (const action of PUBLIC_ACTIONS) {
    const existing = await strapi.db
      .query('plugin::users-permissions.permission')
      .findOne({ where: { action, role: publicRole.id } });
    if (!existing) {
      await strapi.db
        .query('plugin::users-permissions.permission')
        .create({ data: { action, role: publicRole.id } });
    }
  }
}

// Crée et publie les cours au premier démarrage uniquement
async function seedCours(strapi) {
  const count = await strapi.documents('api::course.course').count();
  if (count > 0) {
    return;
  }
  for (const cours of COURS) {
    await strapi.documents('api::course.course').create({ data: cours, status: 'published' });
  }
  strapi.log.info(`Seed : ${COURS.length} cours créés`);
}

module.exports = {
  register() {},

  async bootstrap({ strapi }) {
    await openPublicAccess(strapi);
    await seedCours(strapi);
  },
};
