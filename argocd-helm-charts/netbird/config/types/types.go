package types

type Resource struct {
	Name    string   `yaml:"name" mapstructure:"name"`
	Address string   `yaml:"address" mapstructure:"address"`
	Groups  []string `yaml:"groups" mapstructure:"groups"`
}

type RoutingPeer struct {
	Groups []string `yaml:"groups" mapstructure:"groups"`
}

type NetworkConfig struct {
	Name         string        `yaml:"name" mapstructure:"name"`
	Resources    []Resource    `yaml:"resources" mapstructure:"resources"`
	RoutingPeers RoutingPeer   `yaml:"routing_peers" mapstructure:"routing_peers"`
}

type PolicySource struct {
	Groups []string `yaml:"groups" mapstructure:"groups"`
}

type PolicyDestination struct {
	Groups []string `yaml:"groups" mapstructure:"groups"`
}

type Policy struct {
	Source      PolicySource      `yaml:"source" mapstructure:"source"`
	Destination PolicyDestination `yaml:"destination" mapstructure:"destination"`
	Protocol    string            `yaml:"protocol" mapstructure:"protocol"`
	Ports       []string          `yaml:"ports" mapstructure:"ports"`
}

type Config struct {
	Networks []NetworkConfig `yaml:"networks" mapstructure:"networks"`
	Policies []Policy        `yaml:"policies" mapstructure:"policies"`
}
