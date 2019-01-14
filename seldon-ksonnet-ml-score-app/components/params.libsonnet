{
  global: {
    // User-defined global parameters; accessible to all component and environments, Ex:
    // replicas: 4,
  },
  components: {
    // Component-level parameters, defined initially from 'ks prototype use ...'
    // Each object below should correspond to a component in the components/ directory
    "seldon-core": {
      apifeServiceType: "NodePort",
      engineServiceAccount: "default",
      engineUser: "8888",
      grpcMaxMessageSize: "4194304",
      name: "seldon-core",
      namespace: "seldon",
      operatorJavaOpts: "null",
      operatorSpringOpts: "null",
      registry: "null",
      repository: "seldonio",
      seldonVersion: "0.2.6-SNAPSHOT",
      singleNamespace: "true",
      withAmbassador: "true",
      withApife: "false",
      withRbac: "true",
    },
    "test-seldon-ml-score-api": {
      endpoint: "REST",
      image: "alexioannides/seldon-ml-score-component",
      imagePullSecret: "null",
      name: "test-seldon-ml-score-api",
      oauthKey: "null",
      oauthSecret: "null",
      pvcName: "null",
      replicas: 1,
    },
  },
}
