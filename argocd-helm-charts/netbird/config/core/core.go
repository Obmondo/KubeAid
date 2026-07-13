package core

import (
	"fmt"
	"strings"
)

// GenerateNetworkDescription generates the description based on hyphen separators.
func GenerateNetworkDescription(name string) string {
	parts := strings.Split(name, "-")
	if len(parts) < 2 {
		return fmt.Sprintf("Network %s", name)
	}
	return fmt.Sprintf("Network %s located in %s", parts[0], parts[1])
}

// GenerateResourceDescription generates the description based on hyphens and other metadata.
func GenerateResourceDescription(name, groupsStr, address string) string {
	parts := strings.Split(name, "-")

	// 1. Identify the location
	location := ""
	if len(parts) >= 2 {
		location = " located in " + parts[1]
	}

	// 2. Determine base name
	baseName := parts[0]
	if len(parts) == 3 {
		baseName = parts[0] + "-" + parts[2]
	}

	// 3. Format with the location variable
	return fmt.Sprintf("Resource %s%s part of %s pointing to %s", baseName, location, groupsStr, address)
}
