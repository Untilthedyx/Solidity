// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ERC20 {
    function balanceOf(address account) external view returns(uint256);
    function transfer(address to,uint256 value) external returns(bool);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}


contract ERC20Token is ERC20 {
    string public Name;
    string public Symbol;
    uint8 public constant decimals =18;

    uint256 private _totalSupply;

    mapping(address=>uint256) private _balances;
    mapping(address => mapping(address =>uint256)) private _allowances;

    event Transfer(address indexed from ,address indexed to, uint256 value);
    event Approval(address indexed owner,address indexed to,uint256 value);

    address public Owner;

    constructor(string memory _name, string memory _symbol, uint256 _initSupply){
        Name = _name;
        Symbol = _symbol;
        Owner = msg.sender;
        _mint(msg.sender,_initSupply*(10**uint256(decimals)));
    }

    modifier onlyOwner {
        require(Owner==msg.sender,"Only owner");
        _;
    }

    function balanceOf(address account) public view override returns (uint256){
        return _balances[account];
    }

    function transfer(address to, uint256 value) public override returns(bool){
        _transfer(msg.sender,to,value);
        return true;
    }

    function approve(address spender ,uint256 value )public override  returns(bool){
        _approve(msg.sender,spender,value);
        return true;
    }

    function transferFrom(address from , address to , uint256 value)public override returns (bool){
        _spendAllownce(from, msg.sender ,value);
        _transfer(from,to, value);
        return true;
    }

    function mint (address to, uint256 amount)public onlyOwner{
        _mint(to,amount);
    }

    function _transfer(address from, address to , uint256 value) internal {
        require(from !=address(0),"Transfer from zero address");
        require(to != address(0),"Transfer to zero Address");

        uint256 fromBalance =_balances[from];
        require(fromBalance>=value, "Insufficient Balance");

        _balances[from] = fromBalance-value;
        _balances[to]+= value;
        emit Transfer(from , to ,value); 
    }

    function _approve(address owner_,address spender, uint256 value)internal{
        require(owner_!=address(0),"Approve from zero address");
        require(spender !=address(0),"Approve to zero Address");

        _allowances[owner_][spender]=value;

        emit Approval(owner_, spender, value);
    }

    function _spendAllownce(address owner_,address spender, uint256 value)internal{
        uint256 currentAllowance =_allowances[owner_][spender];
        if(currentAllowance!=type(uint256).max){
            require(currentAllowance>=value,"Insufficient Allownce");
            _allowances[owner_][spender]=currentAllowance-value;
        }
    }

    function _mint(address to, uint256 amount) internal {
        require(to!=address(0),"Mint to zero address");
        
        _totalSupply+=amount;
        _balances[to]+=amount;

        emit Transfer(address(0) , to, amount);
    }

    function getTotalSupply() public view returns(uint256){
        return _totalSupply;
    }

    function getAllowance(address owner_, address spender) public view returns(uint256){
        return _allowances[owner_][spender];
    }
}