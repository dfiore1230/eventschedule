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

    // Check server-side session by requesting the list page and capture HTML for diagnostics
    cy.request({ url: '/home?view=list' }).then((resp) => {
      cy.log('home list status: ' + resp.status);
      cy.writeFile('cypress/results/admin-home-response.html', resp.body);

      const body = resp.body || '';
      cy.log('home snippet: ' + (body ? body.substr(0, 800) : '[empty]'));
      const isLoggedIn = /form method="POST" action="\/logout"|<table|E2E Event 1/.test(body);

      if (!isLoggedIn) {
        // Programmatic login didn't create a logged-in session. Inspect /login HTML before doing UI fallback.
        cy.log('Programmatic login did not create a session; fetching /login HTML to decide fallback approach');
        cy.request({ url: '/login' }).then((loginPage) => {
          cy.writeFile('cypress/results/login-page-response.html', loginPage.body);
          const loginBody = loginPage.body || '';
          cy.log('login page snippet: ' + (loginBody ? loginBody.substr(0, 500) : '[empty]'));

          if (!/name="email"/.test(loginBody) || !/name="_token"/.test(loginBody)) {
            // Login page does not contain expected form controls — fail with diagnostic snippet for CI logs
            const snippet = loginBody ? loginBody.substr(0, 500) : '[empty]';
            throw new Error('Login page missing expected form elements; login page snippet: ' + snippet);
          }

          // If login page looks OK, proceed with UI fallback
          cy.visit('/login');
          cy.get('input[name=email]').should('exist').type(seed.admin_email);
          cy.get('input[name=password]').should('exist').type(seed.admin_password, { log: false });
          cy.get('button[type=submit]').should('exist').click();

          // Re-check the list page after UI login
          cy.request({ url: '/home?view=list' }).then((resp2) => {
            cy.log('post-UI-login home status: ' + resp2.status);
            cy.writeFile('cypress/results/admin-home-response-after-fallback.html', resp2.body);
            const body2 = resp2.body || '';
            expect(/form method="POST" action="\/logout"|<table|E2E Event 1/.test(body2), 'login fallback produced admin page').to.be.true;
          });
        });
      }
    });

    // Visit the admin home list view and capture a screenshot for visual diagnostics
    cy.visit('/home?view=list');
    cy.screenshot('admin-after-visit');

    // Ensure list view is loaded (give it extra time on CI)
    cy.get('table', { timeout: 10000 }).should('exist');

    // merged Events panel check - look for section header
    cy.contains(/Events/).should('exist');

    // ensure at least one admin-owned event is present
    cy.contains('E2E Event 1').should('exist');
  });
});