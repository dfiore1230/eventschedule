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
    cy.get('button[type="submit"]').click();

    // ensure we are logged in by visiting /home
    cy.visit('/home');

    // switch to list view by clicking any link with view=list in the href
    cy.get('a[href*="view=list"]').first().click({ force: true });
    cy.get('table').should('exist');

    // merged Events panel check - look for section header
    cy.contains(/Events/).should('exist');

    // ensure at least one admin-owned event is present
    cy.contains('E2E Event 1').should('exist');
  });
});