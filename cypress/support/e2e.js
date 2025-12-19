// Minimal Cypress support file to satisfy CI runner
// Add global Cypress configuration or commands here if needed

// Provide helper commands that seed and teardown E2E test data.
// These routes are protected by Laravel's CSRF middleware, so we
// visit the app first to obtain the CSRF token from the page meta
// and include it in the request headers.

Cypress.Commands.add('seedData', () => {
  cy.visit('/');
  cy.get('meta[name="csrf-token"]').invoke('attr', 'content').then((token) => {
    return cy.request({
      method: 'POST',
      url: '/__test/seed',
      headers: { 'X-CSRF-TOKEN': token, Accept: 'application/json' },
      failOnStatusCode: false,
    }).then((resp) => {
      Cypress.env('seedData', resp.body || {});
      return resp;
    });
  });
});

Cypress.Commands.add('teardownData', () => {
  const seed = Cypress.env('seedData') || {};
  cy.visit('/');
  cy.get('meta[name="csrf-token"]').invoke('attr', 'content').then((token) => {
    return cy.request({
      method: 'POST',
      url: '/__test/teardown',
      body: { event_ids: seed.created_event_ids || [], sale_ids: seed.created_sale_ids || [], user_ids: seed.created_user_ids || [] },
      headers: { 'X-CSRF-TOKEN': token, Accept: 'application/json' },
      failOnStatusCode: false,
    });
  });
});
