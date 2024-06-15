#[starknet::contract]
pub mod Ticket {
    use core::num::traits::zero::Zero;
    use openzeppelin::access::ownable::ownable::OwnableComponent::InternalTrait;
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin::token::erc721::interface::{IERC721Dispatcher, IERC721DispatcherTrait};
    use starkcon::interfaces::{{INFTDispatcher, INFTDispatcherTrait}, ITicket};

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        fee_collected: u256,
        total_registered_attenders: u64,
        token_base_id: u256,
        platform_admin: ContractAddress,
        event_detail: EventDetail,
        registered: LegacyMap::<ContractAddress, bool>,
        attended: LegacyMap::<ContractAddress, bool>,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[derive(Copy, Drop, Serde, starknet::Store)]
    pub struct EventDetail {
        event_id: u256,
        fee: u256,
        token_base_id: u256,
        capacity: u64,
        event_admin: ContractAddress,
        nft_address: ContractAddress,
        spok: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Registered: Registered,
        SpokClaimed: SpokClaimed,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    #[derive(Copy, Drop, starknet::Event)]
    struct Registered {
        caller: ContractAddress
    }

    #[derive(Copy, Drop, starknet::Event)]
    struct SpokClaimed {
        caller: ContractAddress,
        token_id: u256
    }

    mod Errors {
        pub const ZERO_ADDRESS_CALLER: felt252 = 'Register: Zero Address caller';
        pub const ZERO_ADDRESS_RECEIVER: felt252 = 'Withdraw: Zero Address receiver';
        pub const ZERO_ADDRESS_TOKEN: felt252 = 'Withdraw: Zero Address token';
        pub const INSUFFICIENT_AMOUNT: felt252 = 'Register: Insufficient fee';
        pub const INSUFFICIENT_BALANCE: felt252 = 'Withdraw: Insufficient balance';
        pub const NOT_REGISTERED: felt252 = 'Claim_spok: user not registered';
        pub const CAPACITY_REACHED: felt252 = 'register: capacity met';
        pub const MISSING_RECORD: felt252 = 'join: not registered for event';
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        fee: u256,
        event_id: u256,
        capacity: u64,
        factory: ContractAddress,
        event_admin: ContractAddress,
        platform_admin: ContractAddress,
        nft_address: ContractAddress,
        spok: ContractAddress
    ) {
        self.ownable.initializer(event_admin);
        self.platform_admin.write(platform_admin);
        self
            .event_detail
            .write(
                EventDetail {
                    event_id, fee, token_base_id: 0, capacity, event_admin, nft_address, spok
                }
            );
    }

    #[abi(embed_v0)]
    impl ITicketImpl of ITicket<ContractState> {
        fn register(ref self: ContractState, amount: u256, token: ContractAddress) {
            let total_registered_attenders = self.total_registered_attenders.read();
            let capacity = self.event_detail.read().capacity;
            assert(total_registered_attenders < capacity, Errors::CAPACITY_REACHED);
            assert(get_caller_address().is_non_zero(), Errors::ZERO_ADDRESS_CALLER);
            assert(amount >= self.event_detail.read().fee, Errors::INSUFFICIENT_AMOUNT);
            self._register(amount, token);
        }

        fn join(ref self: ContractState) {
            let caller = get_caller_address();
            assert(self.registered.read(caller) == true, Errors::MISSING_RECORD);
            self.attended.write(caller, true);
        }

        fn withdraw(
            ref self: ContractState, to: ContractAddress, amount: u256, token: ContractAddress
        ) {
            self.ownable.assert_only_owner();
            assert(to.is_non_zero(), Errors::ZERO_ADDRESS_RECEIVER);
            assert(token.is_non_zero(), Errors::ZERO_ADDRESS_TOKEN);
            assert(
                amount >= IERC20Dispatcher { contract_address: token }
                    .balance_of(get_contract_address()),
                Errors::INSUFFICIENT_BALANCE
            );
            self._withdraw(to, amount, token);
        }

        fn claim_spok(
            ref self: ContractState,
            token_id: u256,
            spok_address: ContractAddress,
            spok_holder: ContractAddress
        ) {
            let caller: ContractAddress = get_caller_address();
            assert(self.attended.read(caller), Errors::MISSING_RECORD);
            IERC721Dispatcher { contract_address: spok_address }
                .transfer_from(spok_holder, caller, token_id);
            self.emit(SpokClaimed { caller, token_id });
        }

        fn get_event_details(self: @ContractState) -> EventDetail {
            self.event_detail.read()
        }

        fn get_total_registered_attenders(self: @ContractState) -> u64 {
            self.total_registered_attenders.read()
        }
    }

    #[generate_trait]
    impl Private of PrivateTrait {
        fn _withdraw(
            ref self: ContractState, to: ContractAddress, amount: u256, token: ContractAddress
        ) {
            let strk_contract_mainnet: ContractAddress =
                0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d
                .try_into()
                .unwrap();
            let usdt_contract_mainnet: ContractAddress =
                0x068f5c6a61780768455de69077e07e89787839bf8166decfbf92b645209c0fb8
                .try_into()
                .unwrap();
            let usdc_contract_mainnet: ContractAddress =
                0x053c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8
                .try_into()
                .unwrap();
            if token == strk_contract_mainnet {
                IERC20Dispatcher { contract_address: token }.transfer(to, amount);
            };
            if token == usdt_contract_mainnet {
                IERC20Dispatcher { contract_address: token }.transfer(to, amount);
            };
            if token == usdc_contract_mainnet {
                IERC20Dispatcher { contract_address: token }.transfer(to, amount);
            };
        }

        fn _register(ref self: ContractState, amount: u256, token: ContractAddress) {
            let caller: ContractAddress = get_caller_address();
            let nft_address = self.event_detail.read().nft_address;
            let mut total_registered_attenders = self.total_registered_attenders.read();
            let mut token_id = self._increment();
            let data: Array<felt252> = ArrayTrait::new();

            if self.event_detail.read().fee == 0 {
                INFTDispatcher { contract_address: nft_address }
                    .safe_mint(caller, token_id, data.span());
                self.registered.write(caller, true);
                total_registered_attenders += 1;
                self.token_base_id.write(token_id);
                self.emit(Registered { caller: get_caller_address() });
            } else {
                let event_contract: ContractAddress = get_contract_address();
                let mut fee_collected: u256 = self.fee_collected.read();
                let strk_contract_mainnet: ContractAddress =
                    0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d
                    .try_into()
                    .unwrap();
                let usdt_contract_mainnet: ContractAddress =
                    0x068f5c6a61780768455de69077e07e89787839bf8166decfbf92b645209c0fb8
                    .try_into()
                    .unwrap();
                let usdc_contract_mainnet: ContractAddress =
                    0x053c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8
                    .try_into()
                    .unwrap();
                if token == strk_contract_mainnet {
                    IERC20Dispatcher { contract_address: token }
                        .transfer_from(caller, event_contract, amount);
                    INFTDispatcher { contract_address: nft_address }
                        .safe_mint(caller, token_id, data.span());
                    self.registered.write(get_caller_address(), true);
                    fee_collected += amount;
                    total_registered_attenders += 1;
                };
                if token == usdt_contract_mainnet {
                    IERC20Dispatcher { contract_address: token }
                        .transfer_from(caller, event_contract, amount);
                    INFTDispatcher { contract_address: nft_address }
                        .safe_mint(caller, token_id, data.span());
                    self.registered.write(get_caller_address(), true);
                    fee_collected += amount;
                    total_registered_attenders += 1;
                };
                if token == usdc_contract_mainnet {
                    IERC20Dispatcher { contract_address: token }
                        .transfer_from(caller, event_contract, amount);
                    INFTDispatcher { contract_address: nft_address }
                        .safe_mint(caller, token_id, data.span());
                    self.registered.write(get_caller_address(), true);
                    fee_collected += amount;
                    total_registered_attenders += 1;
                };
                self.token_base_id.write(token_id);
                self.emit(Registered { caller: get_caller_address() });
            }
        }

        fn _increment(ref self: ContractState) -> u256 {
            let token_id = self.token_base_id.read();
            (token_id + 1_u256)
        }
    }
}
