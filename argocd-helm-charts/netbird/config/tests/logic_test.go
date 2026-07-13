package tests

import (
	"testing"

	"github.com/obmondo/kubeaid/argocd-helm-charts/netbird/config/core"
)

func TestGenerateNetworkDescription(t *testing.T) {
	tests := []struct {
		name     string
		expected string
	}{
		{"network", "Network network"},
		{"haslevbio-haslev", "Network haslevbio located in haslev"},
	}

	for _, tt := range tests {
		result := core.GenerateNetworkDescription(tt.name)
		if result != tt.expected {
			t.Errorf("Expected %s, got %s", tt.expected, result)
		}
	}
}

func TestGenerateResourceDescription(t *testing.T) {
	tests := []struct {
		name     string
		groups   string
		address  string
		expected string
	}{
		{"res", "group1", "1.1.1.1/24", "Resource res part of group1 pointing to 1.1.1.1/24"},
		{"haslevbio-haslev", "group1", "1.1.1.1/24", "Resource haslevbio located in haslev part of group1 pointing to 1.1.1.1/24"},
		{"haslevbio-haslev-backend01", "group1", "1.1.1.1/24", "Resource haslevbio-backend01 located in haslev part of group1 pointing to 1.1.1.1/24"},
	}

	for _, tt := range tests {
		result := core.GenerateResourceDescription(tt.name, tt.groups, tt.address)
		if result != tt.expected {
			t.Errorf("Expected %s, got %s", tt.expected, result)
		}
	}
}
