local env = std.extVar("__ksonnet/environments");
local params = std.extVar("__ksonnet/params").components["seldon-core"];

local k = import "k.libsonnet";
local core = import "seldon-core/seldon-core/core.libsonnet";

// updatedParams uses the environment namespace if
// the namespace parameter is not explicitly set
local updatedParams = params {
  namespace: if params.namespace == "null" then env.namespace else params.namespace,
};

local registry = params.registry;
local repository = params.repository;
local seldonVersion = params.seldonVersion;
local singleNamespace = params.singleNamespace;

local name = params.name;
local namespace = updatedParams.namespace;
local withRbac = params.withRbac;
local withApife = params.withApife;
local withAmbassador = params.withAmbassador;

// APIFE
local apifeImage = if registry == "null" then repository + "/apife:" + seldonVersion else registry + "/" + repository + "/apife:" + seldonVersion;
local apifeServiceType = params.apifeServiceType;
local grpcMaxMessageSize = params.grpcMaxMessageSize;

// Cluster Manager (The CRD Operator)
local operatorImage = if registry == "null" then repository + "/cluster-manager:" + seldonVersion else registry + "/" + repository + "/cluster-manager:" + seldonVersion;
local operatorSpringOptsParam = params.operatorSpringOpts;
local operatorSpringOpts = if operatorSpringOptsParam != "null" then operatorSpringOptsParam else "";
local operatorJavaOptsParam = params.operatorJavaOpts;
local operatorJavaOpts = if operatorJavaOptsParam != "null" then operatorJavaOptsParam else "";

// Engine
local engineImage = if registry == "null" then repository + "/engine:" + seldonVersion else registry + "/" + repository + "/engine:" + seldonVersion;
local engineServiceAccount = params.engineServiceAccount;
local engineUser = params.engineUser;

// APIFE
local apife = [
  core.parts(name, namespace, seldonVersion, singleNamespace).apife(apifeImage, withRbac, grpcMaxMessageSize),
  core.parts(name, namespace, seldonVersion, singleNamespace).apifeService(apifeServiceType),
];

local rbac2_single_namespace = [
  core.parts(name, namespace, seldonVersion, singleNamespace).rbacServiceAccount(),
  core.parts(name, namespace, seldonVersion, singleNamespace).rbacRole(),
  core.parts(name, namespace, seldonVersion, singleNamespace).rbacRoleBinding(),
];

local rbac2_cluster_wide = [
  core.parts(name, namespace, seldonVersion, singleNamespace).rbacServiceAccount(),
  core.parts(name, namespace, seldonVersion, singleNamespace).rbacClusterRole(),
  core.parts(name, namespace, seldonVersion, singleNamespace).rbacClusterRoleBinding(),  
  core.parts(name, namespace, seldonVersion, singleNamespace).rbacCRDClusterRole(),
  core.parts(name, namespace, seldonVersion, singleNamespace).rbacCRDClusterRoleBinding(),  
];

local rbac1 = [
  core.parts(name, namespace, seldonVersion, singleNamespace).rbacServiceAccount(),
  core.parts(name, namespace, seldonVersion, singleNamespace).rbacRoleBinding(),
];

local rbac = if std.startsWith(seldonVersion, "0.1") then rbac1 else if singleNamespace == "true" then rbac2_single_namespace else rbac2_cluster_wide;

// Core
local coreComponents = [
  core.parts(name, namespace, seldonVersion, singleNamespace).deploymentOperator(engineImage, operatorImage, operatorSpringOpts, operatorJavaOpts, withRbac, engineServiceAccount, engineUser),
  core.parts(name, namespace, seldonVersion, singleNamespace).redisDeployment(),
  core.parts(name, namespace, seldonVersion, singleNamespace).redisService(),
  core.parts(name, namespace, seldonVersion, singleNamespace).crd(),
];

//Ambassador
local ambassadorRbac_single_namespace = [
  core.parts(name,namespace, seldonVersion, singleNamespace).rbacAmbassadorRole(),
  core.parts(name,namespace, seldonVersion, singleNamespace).rbacAmbassadorRoleBinding(),  
];

local ambassadorRbac_cluster_wide = [
  core.parts(name,namespace, seldonVersion, singleNamespace).rbacAmbassadorClusterRole(),
  core.parts(name,namespace, seldonVersion, singleNamespace).rbacAmbassadorClusterRoleBinding(),  
];

local ambassador = [
  core.parts(name,namespace, seldonVersion, singleNamespace).ambassadorDeployment(),
  core.parts(name,namespace, seldonVersion, singleNamespace).ambassadorService(),  
];

local l1 = if withRbac == "true" then rbac + coreComponents else coreComponents;
local l2 = if withApife == "true" then l1 + apife else l1;
local l3 = if withAmbassador == "true" && withRbac == "true" && singleNamespace == "true" then l2 + ambassadorRbac_single_namespace else l2;
local l4 = if withAmbassador == "true" && withRbac == "true" && singleNamespace == "false" then l3 + ambassadorRbac_cluster_wide else l3;
local l5 = if withAmbassador == "true" then l4 + ambassador else l4;

l5