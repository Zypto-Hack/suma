#[starknet::contract]
pub mod Factore {
    use core::num::traits::zero::Zero;
    use openzeppelin::access::ownable::ownable::OwnableComponent::InternalTrait;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::upgrades::UpgradeableComponent;
    use starknet::{syscalls::deploy_syscall, ContractAddress, ClassHash, get_contract_address};
    use starkcon::interfaces::IFactory;
    use starkcon::nft::NFT;
    use alexandria_storage::list::{IndexView, ListTrait, List};


    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        platform_admin: ContractAddress,
        spok_address: ContractAddress,
        nft_classhash: ClassHash,
        child_classhash: ClassHash,
        events: List::<ContractAddress>,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        EventCreated: EventCreated,
        NftClasshashUpdated: NftClasshashUpdated,
        ChildClasshashUpdated: ChildClasshashUpdated,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    struct EventCreated {
        created_by: ContractAddress,
        event_address: ContractAddress,
        nft_address: ContractAddress,
        event_id: u64
    }

    #[derive(Drop, starknet::Event)]
    struct ChildClasshashUpdated {
        updated_by: ContractAddress,
        time: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct NftClasshashUpdated {
        updated_by: ContractAddress,
        time: u64,
    }

    mod Errors {
        pub const ZERO_ADDRESS_SPOK: felt252 = 'update_spok: zero address';
        pub const ZERO_CLASSHASH: felt252 = 'classhash cannot be zero';
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        platform_admin: ContractAddress,
        spok_address: ContractAddress,
        child_classhash: ClassHash,
        nft_classhash: ClassHash
    ) {
        self.ownable.initializer(platform_admin);
        self.platform_admin.write(platform_admin);
        self.child_classhash.write(child_classhash);
        self.nft_classhash.write(nft_classhash);
        self.spok_address.write(spok_address);
    }

    #[abi(embed_v0)]
    impl IFactoryImpl of IFactory<ContractState> {
        fn create_event(
            ref self: ContractState,
            fee: u256,
            event_id: u64,
            capacity: u64,
            name: ByteArray,
            symbol: ByteArray,
            uri: ByteArray,
            event_admin: ContractAddress
        ) {
            let factore = get_contract_address();
            let platform_admin = self.platform_admin.read();
            let child_classhash = self.child_classhash.read();
            let nft_classhash = self.nft_classhash.read();
            let spok_address = self.spok_address.read();
            let mut events = self.events.read();

            let mut calldata = ArrayTrait::new();
            let mut nft_calldata = ArrayTrait::new();

            event_admin.serialize(ref nft_calldata);
            name.serialize(ref nft_calldata);
            symbol.serialize(ref nft_calldata);
            uri.serialize(ref nft_calldata);
            let (nft_address, _) = deploy_syscall(nft_classhash, 0, nft_calldata.span(), false)
                .expect('deploy_syscall fail');

            fee.serialize(ref calldata);
            event_id.serialize(ref calldata);
            factore.serialize(ref calldata);
            event_admin.serialize(ref calldata);
            platform_admin.serialize(ref calldata);
            nft_address.serialize(ref calldata);
            spok_address.serialize(ref calldata);
            let (event_address, _) = deploy_syscall(child_classhash, 0, calldata.span(), false)
                .expect('deploy syscall fail');

            events.append(event_address);

            self
                .emit(
                    EventCreated {
                        created_by: starknet::get_caller_address(),
                        event_address,
                        nft_address,
                        event_id
                    }
                );
        }

        fn update_child_classhash(ref self: ContractState, new_child_classhash: ClassHash) {
            self.ownable.assert_only_owner();
            assert(new_child_classhash.is_non_zero(), Errors::ZERO_CLASSHASH);
            self.child_classhash.write(new_child_classhash);
            self
                .emit(
                    ChildClasshashUpdated {
                        updated_by: starknet::get_caller_address(),
                        time: starknet::get_block_timestamp(),
                    }
                );
        }

        fn update_nft_classhash(ref self: ContractState, new_nft_classhash: ClassHash) {
            self.ownable.assert_only_owner();
            assert(new_nft_classhash.is_non_zero(), Errors::ZERO_CLASSHASH);
            self.nft_classhash.write(new_nft_classhash);
            self
                .emit(
                    NftClasshashUpdated {
                        updated_by: starknet::get_caller_address(),
                        time: starknet::get_block_timestamp(),
                    }
                );
        }

        fn update_spok_address(ref self: ContractState, new_spok_address: ContractAddress) {
            self.ownable.assert_only_owner();
            assert(new_spok_address.is_non_zero(), Errors::ZERO_ADDRESS_SPOK);
            self.spok_address.write(new_spok_address);
        }

        fn get_factory_address(self: @ContractState) -> ContractAddress {
            get_contract_address()
        }
    }

    #[abi(embed_v0)]
    fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
        self.ownable.assert_only_owner();
        assert(new_class_hash.is_non_zero(), Errors::ZERO_CLASSHASH);
        self.upgradeable._upgrade(new_class_hash);
    }


    #[abi(embed_v0)]
    fn get_events(self: @ContractState) -> List<ContractAddress> {
        self.events.read()
    }
}
