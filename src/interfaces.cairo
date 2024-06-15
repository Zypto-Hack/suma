use starkcon::ticket::Ticket::EventDetail;
use starknet::{ClassHash, ContractAddress};


#[starknet::interface]
pub trait ITicket<TContractState> {
    fn register(ref self: TContractState, amount: u256, token: ContractAddress);
    fn withdraw(
        ref self: TContractState, to: ContractAddress, amount: u256, token: ContractAddress
    );
    fn claim_spok(
        ref self: TContractState,
        token_id: u256,
        spok_address: ContractAddress,
        spok_holder: ContractAddress
    );
    fn join(ref self: TContractState);
    fn get_event_details(self: @TContractState) -> EventDetail;
    fn get_total_registered_attenders(self: @TContractState) -> u64;
}

#[starknet::interface]
pub trait IFactory<TContractState> {
    fn create_event(
        ref self: TContractState,
        fee: u256,
        event_id: u64,
        capacity: u64,
        name: ByteArray,
        symbol: ByteArray,
        uri: ByteArray,
        event_admin: ContractAddress
    );

    fn update_child_classhash(ref self: TContractState, new_child_classhash: ClassHash);
    fn update_nft_classhash(ref self: TContractState, new_nft_classhash: ClassHash);
    fn update_spok_address(ref self: TContractState, new_spok_address: ContractAddress);
    fn get_factory_address(self: @TContractState) -> ContractAddress;
}

#[starknet::interface]
pub trait INFT<TContractState> {
    fn safe_mint(
        ref self: TContractState, to: ContractAddress, token_id: u256, data: Span<felt252>
    );
}
