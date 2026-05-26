# Changelog

## [1.3.0](https://github.com/Gabriele-bil/dev_flow/compare/devflow-v1.2.0...devflow-v1.3.0) (2026-05-26)


### Features

* Add devflow.blueprint skill for multi-PR planning with dependency graph and adversarial review ([0fe759c](https://github.com/Gabriele-bil/dev_flow/commit/0fe759cc2c7eaedf9b2b2feb2499150330008256))
* **hooks:** Register observe.sh stop as Stop lifecycle hook ([db8b460](https://github.com/Gabriele-bil/dev_flow/commit/db8b4607af178ffb0f7a352102eaa5835891bc0d))
* Implement retry-loop detection in observe.sh to log consecutive error events and prevent duplicate entries in learnings ([04e8ca5](https://github.com/Gabriele-bil/dev_flow/commit/04e8ca5fa8499c5fca34d6a7ff76bfe2add0bb46))
* Introduce devflow-ship skill for pre-merge gate process, enabling parallel dispatch of code-reviewer, security-auditor, and test-engineer agents ([a23a4d5](https://github.com/Gabriele-bil/dev_flow/commit/a23a4d5351fc45ee1e548f89b89dd363cd0d7f42))
* Migrate learning system to structured instincts in YAML format ([4b5ba31](https://github.com/Gabriele-bil/dev_flow/commit/4b5ba31f824dbc93965a787364885d7dce3e67ca))
* **observe:** Add stop event handler for compact advisory ([e0203ba](https://github.com/Gabriele-bil/dev_flow/commit/e0203ba6690b16c7fec4a8e8cb8116f836e00e55))
* **observe:** Add tool-call counter and step-change compact advisory ([6063dc9](https://github.com/Gabriele-bil/dev_flow/commit/6063dc9ea602223ab25e812841ef223e433dd18c))

## [1.2.0](https://github.com/Gabriele-bil/dev_flow/compare/devflow-v1.1.0...devflow-v1.2.0) (2026-05-22)


### Features

* Add flutter-architecture skill and update flutter-layout to prefer Row/Column spacing parameter over SizedBox ([6669e79](https://github.com/Gabriele-bil/dev_flow/commit/6669e79e15b4437811e61b054a5b4eb5fee4b512))

## [1.1.0](https://github.com/Gabriele-bil/dev_flow/compare/devflow-v1.0.0...devflow-v1.1.0) (2026-05-22)


### Features

* Add accessibility-auditor and docs-reviewer agents to devflow orchestration ([0b0b3e0](https://github.com/Gabriele-bil/dev_flow/commit/0b0b3e0ee1f725edd9a412bf5461f847c217e1e8))
* Add antigravity support ([d38e9db](https://github.com/Gabriele-bil/dev_flow/commit/d38e9dbe6c2d42c6962efacc607cbecbd868b2b5))
* Add common-caveman skill definition for token-efficient technical responses ([e56f05f](https://github.com/Gabriele-bil/dev_flow/commit/e56f05fe7a54832fa0f91a2a1a804f2944af3687))
* Add common-clean-code skill and integrate into implementation and planning workflows ([649355c](https://github.com/Gabriele-bil/dev_flow/commit/649355cdae792c6fa2feb55309487d9f628eb6ca))
* Add common-web-interface-guidelines skill and integrate into ADAPTER schema and Next.js workflow ([36a200e](https://github.com/Gabriele-bil/dev_flow/commit/36a200ecc9f106c0d02a110ffe15fd857a49e778))
* Add DevFlow configuration agent, pipeline hooks, and standardized context templates ([62f311f](https://github.com/Gabriele-bil/dev_flow/commit/62f311fbd5213e514cbce56dbd502c17bda73ac5))
* Add I/O references and standardized formatting to skill definitions while introducing new devflow status, validation, and hook scripts. ([9d555da](https://github.com/Gabriele-bil/dev_flow/commit/9d555dad57f4cc7f78c75998c28e006417f4c3a8))
* Add marketplace.json configuration for devflow plugin registration ([51e2f38](https://github.com/Gabriele-bil/dev_flow/commit/51e2f387c90ac6509d72cf72c320615fcc6504e5))
* Add Next.js adapter support to agent configuration and define UI/UX architecture skills ([1154830](https://github.com/Gabriele-bil/dev_flow/commit/1154830ed49b57305de57feefc28e60728f3d680))
* Add nextjs-metadata and nextjs-performance skills and update existing Next.js skill documentation ([dd0bd04](https://github.com/Gabriele-bil/dev_flow/commit/dd0bd04baca13bc546da1eaca457b59280c8e322))
* Add preflight check in session-start for unconfigured config.md ([b9a7d2d](https://github.com/Gabriele-bil/dev_flow/commit/b9a7d2d83b4c94b4368dd88d7f3f8498241e771d))
* Add support for Next.js stack detection in SKILL.md documentation ([c75589e](https://github.com/Gabriele-bil/dev_flow/commit/c75589ebb8b8343b585c1cefb997d040e8532e57))
* Implement automated task numbering via .devflow-state.json and hooks to eliminate redundant directory scans. ([4984855](https://github.com/Gabriele-bil/dev_flow/commit/4984855ead12df72815bd4efa00a7c0cb3b530a6))
* Implement devflow learning system including core principles, session hooks, and validation scripts ([51bb1a2](https://github.com/Gabriele-bil/dev_flow/commit/51bb1a259d545bf7194a7b0d73dde929318f0f1c))
* Improve AI generation quality across DevFlow pipeline ([527ec5c](https://github.com/Gabriele-bil/dev_flow/commit/527ec5c94cfec92d808d9d93862d965a9c9a967a))
* Introduce DevFlow plugin with core components, agents, skills, and configuration files ([3854ae6](https://github.com/Gabriele-bil/dev_flow/commit/3854ae607bda3014293c9cd764d10ea6509950c7))
* Introduce PRODUCT.template.md for Flutter adapter and update setup command to generate product context documentation ([616b697](https://github.com/Gabriele-bil/dev_flow/commit/616b6979af8cd806633c5dba5c44f729d317bda9))


### Bug Fixes

* Add .devflow-state.json to .gitignore ([3cf94f2](https://github.com/Gabriele-bil/dev_flow/commit/3cf94f272ef06f8efee1050390be37e6fce0825e))
* Add missing I/O Reference section to common-web-interface-guidelines skill ([c559816](https://github.com/Gabriele-bil/dev_flow/commit/c55981665a33431391d9e7fa4adfda90d97ca7c2))
* Plugin structure ([7853fbd](https://github.com/Gabriele-bil/dev_flow/commit/7853fbdf5b8181b1c5c9adf08a96bbbb95329dd9))
* Remove description from hooks ([bf345e0](https://github.com/Gabriele-bil/dev_flow/commit/bf345e0d82d173babf65d2687e66ce1db5a2e0af))
* Setup ([804cff7](https://github.com/Gabriele-bil/dev_flow/commit/804cff7347b9be41d8f7b25098eb418bfedab1c4))
* Update plugin.json — add Next.js to description and declare hooks path ([f4de0b1](https://github.com/Gabriele-bil/dev_flow/commit/f4de0b196da62f35ff34fa3aa1e46f89406454ce))

## Changelog
