 pragma solidity  >=0.4.24 <0.9.0;

    contract TRC20 {
       function transfer(address recipient, uint256 amount) public returns (bool);
       function transferFrom(address sender, address recipient, uint256 amount) public returns (bool);
       function balanceOf(address account) public returns (uint256);
    }