export class AdminState {
  constructor(initial = {}) {
    this.value = { session: 'unknown', page: 'overview', ...initial };
    this.listeners = new Set();
  }

  update(patch) {
    this.value = { ...this.value, ...patch };
    for (const listener of this.listeners) listener(this.value);
  }

  subscribe(listener) {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }
}
