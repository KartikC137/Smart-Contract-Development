// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

// Manually implementing all the functions of ERC20 standard token
contract ManualToken {
    /*Token: */

    mapping(address => uint256) private s_balances;

    /*This is a Token, a value that is held by an address.*/
    function name() public pure returns (string memory) {
        return "Manual Token";
    }

    function symbol() public pure returns (string memory) {
        return "KEK";
    }

    function decimals() public pure returns (uint8) {
        return 18;
    }

    function totalSupply() public pure returns (uint256) {
        return 100 ether;
    }

    function balanceOf(address _owner) public view returns (uint256 balance) {
        return s_balances[_owner];
    }

    function transfer(address _to, uint256 _value) public {
        uint256 previousBalances = balanceOf(msg.sender) + balanceOf(_to);
        s_balances[msg.sender] -= _value;
        s_balances[_to] += _value;
        require(balanceOf(msg.sender) + balanceOf(_to) == previousBalances);
    }

    // and so on.. for all the functions of ERC20 standard
}
