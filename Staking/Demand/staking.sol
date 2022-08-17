// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.24 <0.9.0;
import './trc20.sol';

contract EOTC_Staking {
  address private owner;
  address eotc_ads;
  address xeotc_ads;
  address apvads;
  uint256 arp; 
  uint256 xarp; 
  uint256 sday; 
  //uint256 smonth6;
  //uint256 syear;
  uint256 stakeSum;
  uint256 stakeNum;
  uint256 stakeSumX;
  uint256 stakeNumX;

  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }
  struct stakingMes {
      uint256 amount;
      uint256 sdate;
      bool isStake;
  }
  mapping(address => stakingMes) staking;

  constructor() public{
    owner=msg.sender;
    apvads=msg.sender;
    eotc_ads=0xDfe9d10781d0e48bCc03f0FDa2067E45AEc6A144;
    xeotc_ads=0xc3a272e48D73EbB2819DE59b29E23bB18DC0f627;
    //arp=[329,240000,600000,1080000,1680000,3000000];
    arp=329;
    xarp=1000000;
    sday=86400;
    //smonth6=15768000;
    //syear=31536000;
    stakeSum=0;
    stakeNum=0;
    stakeSumX=0;
    stakeNumX=0;
  }
  
 function withdraw(address myaddress,uint256 _eth) onlyOwner public{
    address send_to_address = myaddress;
    send_to_address.transfer(_eth);
  }
  
 function transferIn(uint256 amount,address _tokenAddress)public{
    TRC20 usdt = TRC20(_tokenAddress);
    usdt.transferFrom(msg.sender,address(this), amount);
  }
  
 function transferOut(address myaddress,uint256 amount,address _tokenAddress) onlyOwner public{
    TRC20 usdt = TRC20(_tokenAddress);
    usdt.transfer(myaddress, amount);
  }
  
 function stake(uint256 amount)public returns(bool){    
    TRC20 eotc = TRC20(eotc_ads);
    require(eotc.transferFrom(msg.sender,address(this), amount));
      if(staking[msg.sender].isStake){
        staking[msg.sender].amount=getInfo_eotc(msg.sender)+amount;
        staking[msg.sender].sdate=now;
      }
      else{
        stakingMes memory sm=stakingMes(amount,now,true);
        staking[msg.sender]=sm;
      }
    return true;
 }

 function unstake(uint256 amount)public returns(bool){
   uint256 myamount=getInfo_eotc(msg.sender);
   if(myamount>=amount && amount>0){
      TRC20 eotc = TRC20(eotc_ads);
      require(eotc.transfer(msg.sender, amount));
      staking[msg.sender].amount-=amount;
      staking[msg.sender].sdate=now;
   }
 }

 function getInfo_eotc(address ads)public view returns (uint256){
   uint256 myamount=staking[ads].amount;
   uint256 sk = (now-staking[ads].sdate)/sday;
   return (myamount+sk*myamount*arp);
 }

 function get_stake()public view returns (uint256,uint256){
  return (stakeSum,stakeNum);
 }

 function get_stakeX()public view returns (uint256,uint256){
  return (stakeSumX,stakeNumX);
 }

 function get_arp()public view returns (uint256,uint256){
  return (arp,xarp);
 }
 
 function withdrawalToken(address _tokenAddress) onlyOwner public { 
    TRC20 token = TRC20(_tokenAddress);
    token.transfer(owner, token.balanceOf(this));
}

 function SetArp(uint256 arpv) public returns(bool){ 
     require(msg.sender==apvads || msg.sender==owner);
     arp=arpv;
     xarp+=arpv;
     return true;
 }

 function SetXarp(uint256 xarpv) onlyOwner public returns(bool){ 
     xarp=xarpv;
     return true;
 }

 function Setads(address ads) onlyOwner public returns(bool){ 
     apvads=ads;
     return true;
 }

 function AutoArp() private pure returns(uint256){ 
     return 0;
 } 

 function Staking_eotc(uint256 amount) public returns(bool){ 
    TRC20 eotc = TRC20(eotc_ads);
    require(eotc.transferFrom(msg.sender,address(this), amount));
    TRC20 xeotc = TRC20(xeotc_ads);
    require(xeotc.transfer(msg.sender, amount*1000000/xarp));
    stakeSum+=amount;
    stakeNum+=1;
    return true;
 }

 function Unstaking_eotc(uint256 amount) public returns(bool){ 
   TRC20 xeotc = TRC20(xeotc_ads);
   require(xeotc.transferFrom(msg.sender,address(this), amount));
   TRC20 eotc = TRC20(eotc_ads);
   uint256 asn=amount*xarp/1000000;
   require(eotc.transfer(msg.sender, asn));
   stakeSumX+=asn;
   stakeNumX+=1;
   return true;
 }
}