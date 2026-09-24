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
