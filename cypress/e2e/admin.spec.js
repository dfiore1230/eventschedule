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
    // Programmatic login for determinism: fetch CSRF token then post credentials
    cy.request('/login').then((resp) => {
      const body = resp.body || '';
      const m = body.match(/name="_token" value="([^"]+)"/);
      const token = m ? m[1] : null;
      expect(token, 'csrf token from /login').to.be.a('string');

      cy.request({
        method: 'POST',
        url: '/login',
        form: true,
        body: { _token: token, email: seed.admin_email, password: seed.admin_password },
        followRedirect: true,
      }).then((loginResp) => {
        // Diagnose login response; 200 or 302 are acceptable
        expect([200, 302]).to.include(loginResp.status);
        cy.log('login response status: ' + loginResp.status);
      });
    });

    // Visit the admin home list view and capture diagnostics
    cy.visit('/home?view=list');
    cy.screenshot('admin-after-visit');

    // Save raw HTML for post-mortem if the table isn't present
    cy.request({ url: '/home?view=list' }).then((resp) => {
      cy.log('home list status: ' + resp.status);
      cy.writeFile('cypress/results/admin-home-response.html', resp.body);
    });

    // Ensure list view is loaded (give it extra time on CI)
    cy.get('table', { timeout: 10000 }).should('exist');

    // merged Events panel check - look for section header
    cy.contains(/Events/).should('exist');

    // ensure at least one admin-owned event is present
    cy.contains('E2E Event 1').should('exist');
  });
});