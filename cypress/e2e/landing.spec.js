describe('Landing page flows', () => {
  before(() => {
    // Seed test data via test helper endpoint (only available in local/testing env)
    cy.request({
      method: 'POST',
      url: '/__test/seed',
      failOnStatusCode: false,
    }).then((resp) => {
      // store secrets for later checks if needed
      Cypress.env('seedData', resp.body || {});
    });
  });

  after(() => {
    const seed = Cypress.env('seedData') || {};
    cy.request({
      method: 'POST',
      url: '/__test/teardown',
      body: { event_ids: seed.created_event_ids || [], sale_ids: seed.created_sale_ids || [] },
      failOnStatusCode: false,
    });
  });

  it('renders calendar by default and event times/guest URLs are present', () => {
    const seed = Cypress.env('seedData');
    cy.visit('/');
    cy.contains(/Upcoming Events|This month|calendar/i).should('exist');
    cy.get('#calendar-app').should('exist');

    // check that at least one seeded event name and guest URL are present on the page
    cy.contains(seed.events[0].name).should('exist');
    if (seed.events[0].guest_url) {
      // anchor tag with guest url
      cy.get(`a[href*="${seed.events[0].guest_url}"]`).should('exist');
    }

    // Tooltip test: hover over a calendar element with a tooltip and assert tooltip content
    cy.get('.has-tooltip').first().trigger('mouseenter');
    cy.get('#tooltip').should('be.visible').and('not.be.empty');

    // check event time is visible in list view as well
    const month = new Date(seed.events[0].starts_at).getMonth() + 1;
    const year = new Date(seed.events[0].starts_at).getFullYear();
    cy.visit(`/?view=list&month=${month}&year=${year}`);

    // ensure the event time string appears in the first row
    cy.get('table tbody tr').first().should(($tr) => {
      expect($tr.text()).to.include(new Date(seed.events[0].starts_at).toLocaleString());
    });
  });

  it('seed endpoint returned expected secrets', function () {
    const seed = Cypress.env('seedData');
    expect(seed).to.have.property('entry_secret');
    expect(seed).to.have.property('sale_secret');
  });

  it('switches to list view and paginates', () => {
    const seed = Cypress.env('seedData');
    const month = new Date(seed.events[0].starts_at).getMonth() + 1;
    const year = new Date(seed.events[0].starts_at).getFullYear();

    cy.visit(`/?view=list&month=${month}&year=${year}`);

    cy.get('table').should('exist');

    // check rows count equals page size (10)
    cy.get('table tbody tr').its('length').should('be.lte', 10);

    // confirm pagination nav exists and click page 2
    cy.get('nav').contains('2').click();

    cy.url().should('include', 'page=2');

    // ensure different content on page 2
    cy.get('table tbody tr').first().should(($tr) => {
      const text = $tr.text();
      expect(text).to.not.include(seed.events[0].name);
    });
  });

  it('month navigation preserves view param', () => {
    cy.visit('/?view=list&month=12&year=2025');
    cy.get('a').contains(/Next month|next/).click();
    cy.url().should('include', 'view=list');
  });
});
