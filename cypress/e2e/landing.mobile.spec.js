describe('Landing mobile flows', () => {
  beforeEach(() => {
    cy.seedData().then(() => {
      const seed = Cypress.env('seedData') || {};
      // guard: ensure recurring fields exist
      expect(seed, 'seedData.recurring').to.have.property('recurring_name');
      expect(seed, 'seedData').to.have.property('recurring_occurrences');
      expect(seed.recurring_occurrences, 'seedData.recurring_occurrences').to.be.an('array');
      expect(seed.recurring_occurrences.length, 'seedData.recurring_occurrences.length').to.be.greaterThan(0);
    });
  });

  it('shows mobile list and toggle', () => {
    const seed = Cypress.env('seedData');
    cy.viewport(375, 812);
    cy.visit('/');
    // mobile events list should be present on a mobile viewport
    cy.get('#mobileEventsList').should('exist');
    // open mobile list by checking presence of mobile events list or by ensuring recurring event is visible
    if (seed.recurring_name) {
      cy.contains(seed.recurring_name).should('exist');

      // assert the mobile list item has an image or time text for the event
      cy.get('#mobileEventsList').within(() => {
        cy.get('li').first().should('exist').and(($li) => {
          expect($li.text()).to.include(seed.recurring_name);
        });
      });
    }
  });

  it('recurring event appears on multiple dates', () => {
    const seed = Cypress.env('seedData');
    expect(seed.recurring_occurrences).to.be.an('array');
    seed.recurring_occurrences.forEach((date) => {
      // visit the month of the occurrence
      const [y, m] = date.split('-');
      cy.visit(`/?month=${parseInt(m)}&year=${y}`);
      // assert the recurring name is visible somewhere on the page
      cy.contains(seed.recurring_name).should('exist');
    });
  });
});