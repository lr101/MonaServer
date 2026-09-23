const mutationActions = Object.freeze({
  reports: 'reports.review',
  campaigns: 'campaigns.write',
});

export function reauthenticationActionFor(page) {
  return mutationActions[page] ?? 'admin_mutation';
}
