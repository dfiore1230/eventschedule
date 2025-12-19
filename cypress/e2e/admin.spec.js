describe('Admin flows', () => {
  let seed;

  before(() => {
    cy.seedData().then(() => {
      seed = Cypress.env('seedData') || {};
      // fail fast if expected admin credentials are not present
      expect(seed, 'seedData from /__test/seed').to.have.property('admin_email');
      expect(seed, 'seedData from /__test/seed').to.have.property('admin_password');
    });
  });

  after(() => {
    cy.teardownData();
  });

  it('can log in as admin and see merged Events panel and list view', () => {
    const seed = Cypress.env('seedData');
    // visit login and perform UI login
    cy.visit('/login');
    cy.get('input[name="email"]').type(seed.admin_email);
    cy.get('input[name="password"]').type(seed.admin_password);
    // click the explicit login button to avoid colliding with disabled signup button
    // prefer clicking the explicit login button; if it's not present, press Enter in the password field as a fallback
    cy.get('button[dusk="log-in-button"]').then($btn => {
      if ($btn.length) {
        cy.wrap($btn).click();
      } else {
        cy.get('input[name="password"]').type('{enter}');
      }
    });

    // ensure we are logged in by visiting /home
    cy.visit('/home');

    // ensure list view is loaded; prefer visiting the list view directly for determinism
    cy.visit('/home?view=list');
    cy.get('table').should('exist');

    // merged Events panel check - look for section header
    cy.contains(/Events/).should('exist');

    // ensure at least one admin-owned event is present
    cy.contains('E2E Event 1').should('exist');
  });
});