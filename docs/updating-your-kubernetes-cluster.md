
# **How to work on a Service Window and inform Stakeholders - for Cluster's KubeAid Application Upgrades**


### **1. Service Window** 

Servicewindow: Updates should happen within service windows - that you have advertised to relevant system owners and stakeholders - just in case any downtime occurs - so you know how much time you have before you have to use your backup plan.

If you're a subscriber at [Obmondo](https://obmondo.com/customer/service-window/bookings) we'll take care of this for you automaticly.

### **2. Book the Service Window**

* Begin by creating or scheduling a service window.
* Some windows are created automatically; others are **ad-hoc** and must be manually scheduled.
* For ad-hoc windows, pick a timeslot suitable for the customer and internal operations.

---

### **3. Notify the Customer/stakeHolder**

* Send a detailed service window notification email.
* Use the templates available 

```
Hi,
This is to inform you that the following service window has been 
created:

 Start Time(s):

 - From 2025-12-08 05:00  onwards for 120 minutes

Timezone: Europe/Copenhagen

Cluster: test cluster

Description: Upgrade kubeaid apps to Release tag 20.1.0

Please reach out to us in case of any concerns.

On the day of the update, we will communicate on the Mattermost before 
the update and an in-between progress update and closure update as well.

Regards
XYZ
```

---

### **4. Prepare PRs, Merge in Git, Push Upstream & Update KubeAid Apps**
* Run the KubeAid update script:
  [https://github.com/Obmondo/KubeAid/blob/master/docs/update_kubeaid_argocd_apps.md](https://github.com/Obmondo/KubeAid/blob/master/docs/update_kubeaid_argocd_apps.md)
> [!NOTE]
> If a customer chooses to deploy the Helm chart using different application names—such as traefik-external or traefik-internal—we must manually add each of these names to:
>
> ```
> k8s/<cluster-name>/kube-prometheus/argocd-application-prometheus-rulesprometheusRuleExample.yaml
> ```
>
> This has to be done manually because a single Helm chart can be reused to deploy multiple applications under different names. For example, in Obmondo, traefik is deployed as external, private, etc., each requiring its own entry.

* Ensure all relevant PRs are:
  * **Created**
  * **Reviewed**
  * **Approved**
  * **Merged into Git**
* After merging, **push the updated state to the customer's upstream repo**.
* Pair with a senior engineer to review and validate all changes.
* Confirm that all generated application manifests match what is expected in ArgoCD.

---

### **5. Start With Root App Sync in ArgoCD**

* Start a thread in the customer’s channel(or any other mode of communication) to inform them about the service window and provide the details of  each application along with the version upgrades. separately maintain a list of issues faced in internal channel and discuss it out.

* Locate the **root application** in ArgoCD.
* Ensure the apps listed in the merged PR match the apps defined under the root app.
* Validate each application **before initiating the root sync**.
* Only sync the apps relevant to the service window—not the entire root unless required.

---

### **6. Filter for KubeAid Applications**

* In ArgoCD, apply a filter:

  ```
  project = kubeaid
  ```
* This ensures you work only on **KubeAid-managed apps**.
* Do **not** sync customer-specific apps unless specifically instructed.

---

### **7. Review Diffs & Manifests Carefully**

* For each KubeAid app:

  * Review the **Diff** tab for expected changes.
  * Inspect the **Manifest** to verify:

    * The correct (latest) KubeAid release tag is applied.
* This step prevents accidental or incorrect deployments.

---

### **8. Sync Out-of-Sync Resources**

* Select only the **resources that are out of sync** for the application.
* Use **Selective Sync** instead of syncing the entire app.
* Use **prune** only when required (e.g., removed resources in the PR).

#### **⚠️ Note: Server-Side Apply**

* Sometimes ArgoCD will fail to sync if the **annotation size exceeds the Kubernetes limit**.
* In such cases, you may need to perform a **server-side apply**:

  * Use the **"Apply (server-side)"** option from ArgoCD's UI
* This avoids the annotation size limit and ensures the resource reconciles correctly.

---

### **9. Verify Cluster & App Health**

* Refresh the applications state after syncing.
* Ensure all pods are:

  * **Running**
  * **Healthy**
  * Free from errors or warnings

* When syncing **CloudNative PG (CNPG)** applications:

  * Check the `kind: Cluster` resource using `kubectl` or **k9s**.
  * Syncing CNPG will restart PostgreSQL pods.
  * **Ensure all desired replicas come back up and enter a Ready state** after the sync.
  * Verify leader election, replication roles, and cluster health.

> [!TIP]
> If you're using [Obmondo](https://obmondo.com/why-obmondo), we will handle your service windows end-to-end, including notifications and coordination with stakeholders or technical contacts. If not, you will need to manage service window planning and communication on your own.