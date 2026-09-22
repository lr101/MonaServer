package service

import "testing"

func TestProductionAdminStoreExposesOnlyDurableExecutionCapabilities(t *testing.T) {
	store := NewProductionAdminStore(nil)

	for name, supported := range map[string]bool{
		"fenced claim and finish": func() bool { _, ok := any(store).(FencedAdminJobStore); return ok }(),
		"lease renewal":           func() bool { _, ok := any(store).(AdminJobLeaseRenewer); return ok }(),
		"terminal unknown delivery": func() bool {
			capability, ok := any(store).(TerminalUnknownDeliveryStore)
			return ok && capability.SupportsTerminalUnknownDelivery()
		}(),
		"atomic audit finish": func() bool { _, ok := any(store).(AdminJobItemCommitStore); return ok }(),
		"lease-loss commit":   func() bool { _, ok := any(store).(AdminJobLeaseLossCommitStore); return ok }(),
		"transition audit":    func() bool { _, ok := any(store).(AdminJobItemAuditStore); return ok }(),
	} {
		if !supported {
			t.Errorf("production store does not provide %s", name)
		}
	}
}
