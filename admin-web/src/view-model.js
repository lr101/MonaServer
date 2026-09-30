export function countLabel(page) {
  return `${page?.items?.length ?? 0}${page?.nextCursor ? '+' : ''}`;
}

export function reportUpdatePayload({ revision, status, assignee, note }) {
  const update = { expectedRevision: Number(revision), status };
  if (assignee) update.assignee = assignee;
  if (note?.trim()) update.note = note.trim();
  return update;
}

export function userDisplayName(user) {
  return user.username || user.email || 'Account';
}

export function adminUserUpdatePayload(values = {}) {
  const update = {};
  if (Number.isSafeInteger(values.expectedAuthGeneration) && values.expectedAuthGeneration >= 0) {
    update.expectedAuthGeneration = values.expectedAuthGeneration;
  }
  for (const field of ['username', 'email', 'securityState']) {
    if (typeof values[field] === 'string' && values[field].trim() !== '') update[field] = values[field].trim();
  }
  for (const field of ['passwordDisabled', 'passwordResetRequired', 'communicationOptOut', 'pushOptedOut']) {
    if (typeof values[field] === 'boolean') update[field] = values[field];
  }
  if (Array.isArray(values.adminPermissions)) update.adminPermissions = [...values.adminPermissions];
  return update;
}

export function hasAdminCapability(capabilities = [], required) {
  return Array.isArray(capabilities) && capabilities.some((capability) => capability === 'superadmin' || capability === required);
}

export function canSendUserLoginLink(user, capabilities = []) {
  return Boolean(user?.accountActivated) && Boolean(user?.email) && hasAdminCapability(capabilities, 'campaign.login_link') &&
    user.securityState === 'normal' && !user.passwordDisabled && !user.passwordResetRequired;
}
