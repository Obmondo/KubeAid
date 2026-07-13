package main

import (
	"context"
	"fmt"
	"log/slog"
	"os"
	"reflect"
	"sort"
	"strings"

	"github.com/netbirdio/netbird/shared/management/client/rest"
	"github.com/netbirdio/netbird/shared/management/http/api"
	"github.com/spf13/pflag"
	"github.com/spf13/viper"

	"github.com/obmondo/kubeaid/argocd-helm-charts/netbird/config/core"
	"github.com/obmondo/kubeaid/argocd-helm-charts/netbird/config/types"
)

func extractGroupIDs(groups []api.GroupMinimum) []string {
	ids := make([]string, len(groups))
	for i, g := range groups {
		ids[i] = g.Id
	}
	sort.Strings(ids)
	return ids
}

func getGroupIDs(ctx context.Context, client *rest.Client, groupNames []string) ([]string, error) {
	groupIDs := make([]string, 0, len(groupNames))
	for _, gName := range groupNames {
		group, err := client.Groups.GetByName(ctx, gName)
		if err != nil {
			return nil, fmt.Errorf("failed to get group %s: %w", gName, err)
		}
		groupIDs = append(groupIDs, group.Id)
	}
	sort.Strings(groupIDs)
	return groupIDs, nil
}

func ensureNetwork(ctx context.Context, client *rest.Client, nw types.NetworkConfig) (api.Network, error) {
	networks, err := client.Networks.List(ctx)
	if err != nil {
		return api.Network{}, fmt.Errorf("failed to list networks: %w", err)
	}

	var existingNetwork *api.Network
	for _, n := range networks {
		if n.Name == nw.Name {
			existingNetwork = &n
			break
		}
	}

	desc := core.GenerateNetworkDescription(nw.Name)
	if existingNetwork != nil {
		if *existingNetwork.Description == desc {
			slog.InfoContext(ctx, "Network already exists and up-to-date", slog.String("network_name", nw.Name))
			return *existingNetwork, nil
		}
		slog.InfoContext(ctx, "Updating network description", slog.String("network_name", nw.Name))
		networkReq := api.PutApiNetworksNetworkIdJSONRequestBody{
			Name:        nw.Name,
			Description: &desc,
		}
		updated, err := client.Networks.Update(ctx, existingNetwork.Id, networkReq)
		if err != nil {
			return api.Network{}, fmt.Errorf("failed to update network: %w", err)
		}
		return *updated, nil
	}

	slog.InfoContext(ctx, "Creating network", slog.String("network_name", nw.Name))
	networkReq := &api.NetworkRequest{
		Name:        nw.Name,
		Description: &desc,
	}

	network, err := client.Networks.Create(ctx, *networkReq)
	if err != nil {
		return api.Network{}, fmt.Errorf("failed to create network: %w", err)
	}

	slog.InfoContext(ctx, "Network created", slog.String("network_name", network.Name))
	return *network, nil
}

func ensureResource(ctx context.Context, client *rest.Client, networkID string, resource types.Resource) error {
	resources, err := client.Networks.Resources(networkID).List(ctx)
	if err != nil {
		return fmt.Errorf("failed to list resources: %w", err)
	}

	desiredGroupIDs, err := getGroupIDs(ctx, client, resource.Groups)
	if err != nil {
		return err
	}

	desc := core.GenerateResourceDescription(resource.Name, strings.Join(resource.Groups, ", "), resource.Address)

	var existingResource *api.NetworkResource
	for _, r := range resources {
		if r.Name == resource.Name {
			existingResource = &r
			break
		}
	}

	if existingResource == nil {
		slog.InfoContext(ctx, "Creating resource", slog.String("resource_name", resource.Name))
		resourceReq := &api.NetworkResourceRequest{
			Name:        resource.Name,
			Description: &desc,
			Address:     resource.Address,
			Groups:      desiredGroupIDs,
			Enabled:     true,
		}
		_, err := client.Networks.Resources(networkID).Create(ctx, *resourceReq)
		return err
	}

	existingGroupIDs := []string{}
	if existingResource.Groups != nil {
		existingGroupIDs = extractGroupIDs(existingResource.Groups)
	}

	if existingResource.Address == resource.Address && reflect.DeepEqual(existingGroupIDs, desiredGroupIDs) && existingResource.Enabled == true && *existingResource.Description == desc {
		slog.InfoContext(ctx, "Resource already up-to-date", slog.String("resource_name", resource.Name))
		return nil
	}

	slog.InfoContext(ctx, "Updating resource", slog.String("resource_name", resource.Name))
	resourceReq := api.PutApiNetworksNetworkIdResourcesResourceIdJSONRequestBody{
		Address:     resource.Address,
		Description: &desc,
		Enabled:     true,
		Groups:      desiredGroupIDs,
		Name:        resource.Name,
	}
	_, err = client.Networks.Resources(networkID).Update(ctx, existingResource.Id, resourceReq)
	return err
}

func ensureRouter(ctx context.Context, client *rest.Client, networkID string, nw types.NetworkConfig, routingPeer types.RoutingPeer) error {
	routers, err := client.Networks.Routers(networkID).List(ctx)
	if err != nil {
		return fmt.Errorf("failed to list routers: %w", err)
	}

	allRoutingGroupIDs, err := getGroupIDs(ctx, client, routingPeer.Groups)
	if err != nil {
		return err
	}

	var existingRouter *api.NetworkRouter
	if len(routers) > 0 {
		existingRouter = &routers[0]
	}

	if existingRouter == nil {
		slog.InfoContext(ctx, "Creating router", slog.String("network_name", nw.Name))
		routerReq := &api.NetworkRouterRequest{
			Enabled:    true,
			Masquerade: true,
			Metric:     9999,
			PeerGroups: &allRoutingGroupIDs,
		}
		_, err := client.Networks.Routers(networkID).Create(ctx, *routerReq)
		return err
	}

	existingPeerGroups := []string{}
	if existingRouter.PeerGroups != nil {
		existingPeerGroups = *existingRouter.PeerGroups
	}
	sort.Strings(existingPeerGroups)
	sort.Strings(allRoutingGroupIDs)

	if existingRouter.Enabled == true && existingRouter.Masquerade == true && existingRouter.Metric == 9999 && reflect.DeepEqual(existingPeerGroups, allRoutingGroupIDs) {
		slog.InfoContext(ctx, "Router already up-to-date", slog.String("network_name", nw.Name))
		return nil
	}

	slog.InfoContext(ctx, "Updating router", slog.String("network_name", nw.Name))
	routerReq := api.PutApiNetworksNetworkIdRoutersRouterIdJSONRequestBody{
		Enabled:    true,
		Masquerade: true,
		Metric:     9999,
		PeerGroups: &allRoutingGroupIDs,
	}
	_, err = client.Networks.Routers(networkID).Update(ctx, existingRouter.Id, routerReq)
	return err
}

func ensurePolicy(ctx context.Context, client *rest.Client, policy types.Policy) error {
	policies, err := client.Policies.List(ctx)
	if err != nil {
		return fmt.Errorf("failed to list policies: %w", err)
	}

	srcGroupIDs, err := getGroupIDs(ctx, client, policy.Source.Groups)
	if err != nil {
		return err
	}
	destGroupIDs, err := getGroupIDs(ctx, client, policy.Destination.Groups)
	if err != nil {
		return err
	}

	name := fmt.Sprintf("%s to %s", strings.Join(policy.Source.Groups, ", "), strings.Join(policy.Destination.Groups, ", "))
	desc := fmt.Sprintf("Access %s on %s %s from %s", strings.Join(policy.Destination.Groups, ", "), policy.Protocol, strings.Join(policy.Ports, ", "), strings.Join(policy.Source.Groups, ", "))

	var existingPolicy *api.Policy
	for _, p := range policies {
		if p.Name == name {
			existingPolicy = &p
			break
		}
	}

	// Prepare rule (NetBird policies have rules)
	rule := api.PolicyRuleUpdate{
		Name:         name,
		Description:  &desc,
		Enabled:      true,
		Action:       api.PolicyRuleUpdateActionAccept,
		Sources:      &srcGroupIDs,
		Destinations: &destGroupIDs,
		Protocol:     api.PolicyRuleUpdateProtocol(strings.ToLower(policy.Protocol)),
		Ports:        &policy.Ports,
	}

	if existingPolicy == nil {
		slog.InfoContext(ctx, "Creating policy", slog.String("name", name))
		_, err := client.Policies.Create(ctx, api.PostApiPoliciesJSONRequestBody{
			Name:        name,
			Description: &desc,
			Enabled:     true,
			Rules:       []api.PolicyRuleUpdate{rule},
		})
		return err
	}

	// Idempotency Check
	if len(existingPolicy.Rules) == 0 {
		slog.WarnContext(ctx, "Policy exists but has no rules, will add the configured rule", slog.String("name", name))
	}

	if len(existingPolicy.Rules) > 0 {
		if len(existingPolicy.Rules) > 1 {
			slog.WarnContext(ctx, "Policy has multiple rules; reconciliation will only manage the first rule", slog.String("name", name))
		}

		eRule := existingPolicy.Rules[0]

		eSources := []string{}
		if eRule.Sources != nil {
			eSources = extractGroupIDs(*eRule.Sources)
		}
		sort.Strings(eSources)

		eDestinations := []string{}
		if eRule.Destinations != nil {
			eDestinations = extractGroupIDs(*eRule.Destinations)
		}
		sort.Strings(eDestinations)

		ePorts := []string{}
		if eRule.Ports != nil {
			ePorts = *eRule.Ports
		}
		sort.Strings(ePorts)

		dSources := srcGroupIDs
		sort.Strings(dSources)

		dDestinations := destGroupIDs
		sort.Strings(dDestinations)

		dPorts := policy.Ports
		sort.Strings(dPorts)

		if eRule.Enabled == rule.Enabled &&
			eRule.Action == api.PolicyRuleAction(rule.Action) &&
			reflect.DeepEqual(eSources, dSources) &&
			reflect.DeepEqual(eDestinations, dDestinations) &&
			reflect.DeepEqual(ePorts, dPorts) &&
			strings.EqualFold(string(eRule.Protocol), string(rule.Protocol)) &&
			(eRule.Description != nil && rule.Description != nil && *eRule.Description == *rule.Description) {
			slog.InfoContext(ctx, "Policy already up-to-date", slog.String("name", name))
			return nil
		}
	}

	// Update logic if needed (NetBird policies might need to be PUT or Recreated)
	slog.InfoContext(ctx, "Updating policy", slog.String("name", name))
	_, err = client.Policies.Update(ctx, *existingPolicy.Id, api.PutApiPoliciesPolicyIdJSONRequestBody{
		Name:        name,
		Description: &desc,
		Enabled:     true,
		Rules:       []api.PolicyRuleUpdate{rule},
	})
	return err
}

func runReconciliation(ctx context.Context, client *rest.Client, config types.Config) {
	for _, nw := range config.Networks {
		network, err := ensureNetwork(ctx, client, nw)
		if err != nil {
			slog.ErrorContext(ctx, "Failed to ensure network", slog.String("err", err.Error()), slog.String("network_name", nw.Name))
			continue
		}

		for _, resource := range nw.Resources {
			if err := ensureResource(ctx, client, network.Id, resource); err != nil {
				slog.ErrorContext(ctx, "Failed to ensure resource", slog.String("err", err.Error()), slog.String("resource_name", resource.Name))
			}
		}

		if err := ensureRouter(ctx, client, network.Id, nw, nw.RoutingPeers); err != nil {
			slog.ErrorContext(ctx, "Failed to ensure router", slog.String("err", err.Error()), slog.String("network_name", nw.Name))
		}
	}

	for _, policy := range config.Policies {
		if err := ensurePolicy(ctx, client, policy); err != nil {
			slog.ErrorContext(ctx, "Failed to ensure policy", slog.String("err", err.Error()))
		}
	}
}

func main() {
	ctx := context.Background()

	pflag.String("config", "config.yaml", "Path to config file")
	pflag.Parse()
	viper.BindPFlag("config", pflag.Lookup("config"))
	viper.SetConfigFile(viper.GetString("config"))

	viper.SetEnvPrefix("NETBIRD")
	viper.AutomaticEnv()

	if err := viper.ReadInConfig(); err != nil {
		slog.Error("Error reading config file", "err", err)
		os.Exit(1)
	}

	var config types.Config
	if err := viper.Unmarshal(&config); err != nil {
		slog.Error("Unable to decode into struct", "err", err)
		os.Exit(1)
	}

	mgmtURL := viper.GetString("MGMT_URL")
	apiToken := viper.GetString("API_TOKEN")

	if mgmtURL == "" || apiToken == "" {
		slog.Error("NETBIRD_MGMT_URL and NETBIRD_API_TOKEN must be set")
		os.Exit(1)
	}

	client := rest.New(mgmtURL, apiToken)
	runReconciliation(ctx, client, config)
}
