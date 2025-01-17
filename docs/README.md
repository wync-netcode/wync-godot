
## How to read the project structure

Base game
* The game has some entities (balls, player)
* There is game logic (movement, physics)

Entity tracking
* Each entity is identificable by an id (EnSingleActors, SyActorRegister)

Network connection
* The server and client stablish a connection to communicate (SyNeteLoopbackConnectReq, SyNeteLoopbackConnectRes)

Wync Entity Setup
* The server and client register their local entities (SyWyncSetupSyncBall, SyWyncSetupSyncPlayer)
* Properties (from entities) are registered for synchronization, including setters and getters.
* On the client: Configure which properties to extrapolate or predict (WyncUtils.prop_set_predict)

Wync connection
* The server and client stablish a Wync connection (SyWyncConnectReq, SyWyncConnectRes)
* The server informs the client about which props it owns (SyWyncConnectRes)
    - WyncUtils.prop_set_client_owner(wync_ctx, prop_id, wync_client_id)
    - The client receives the info about ownership (SyWyncReceiveClientInfo)

Wync state syncing
* The server extracts state from the entities (getters) (SyWyncStateExtractor)
* The client saves these states (SyWyncSaveConfirmedStates)

Wync input
TODO: BEFORE DOING THIS WE NEED TO KNOW WHICH PREDICTED TICK WE ARE ON
* The client sends the server the input state it has ownership over. (SyWyncBufferedInputs, SyWyncSendInputs)

Wync runtime
* The client rollbacks and predicts (SyWyncXtrap)
