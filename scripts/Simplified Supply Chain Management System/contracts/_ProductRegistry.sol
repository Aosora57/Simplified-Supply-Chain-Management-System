//SPDX-License-Identifier:UNLICENSE

pragma solidity ^0.8.0;
contract ProductRegistry{
    
    enum Status {Produced,Shipped,Delivered}//商品状态枚举
    enum Role { None, Producer, Transporter, Buyer }// 角色枚举
    
    // 商品结构体
    struct Product {
        uint id;
        string name;
        uint productTime;
        Status productStatus;
        address producer; // 记录生产商
    }

   // 存储商品
    mapping(uint => Product) public products;
    // 存储地址的角色
    mapping(address => Role) public roles;
    // 存储产品对应的买方
    mapping(uint => address) public productBuyers;



    
    event ProductAdded(uint indexed id, string name, address indexed producer);//产品生产
    event StatusUpdated(uint indexed id, Status status, address indexed updater);//状态更新
    event ProductQueried(uint indexed id, address indexed querier);//数据查询 记录查询id与查询者
    event RoleAssigned(address indexed account, Role role);//角色指定
    event BuyerAssigned(uint indexed id, address indexed buyer);//买家指定
    
    // 权限控制：合约拥有者
    address public owner;
    // 构造函数：初始化 owner
    constructor() {
        owner = msg.sender;
        roles[msg.sender] = Role.Producer; // 默认 owner 为生产商
    }

    // 权限管理：仅限特定角色
    modifier onlyRole(Role _role) {
        require(roles[msg.sender] == _role, "Unauthorized: Invalid role");
        _;
    }

    // 权限管理：仅限 owner
    modifier onlyOwner() {
        require(msg.sender == owner, "Unauthorized: Not owner");
        _;
    }
    // 为什么用 memory？
    // 效率：字符串（如 string）是动态大小的数据类型，直接操作 storage 中的字符串会非常昂贵（需要多次读写区块链）。使用 memory 可以先在内存中处理字符串，减少 gas 消耗。
    // 临时性：_name 只在函数执行时需要，声明为 memory 确保它不会占用区块链的持久存储空间。
    // 默认行为：对于复杂数据类型（如 string、array、struct）作为函数参数时，Solidity 要求显式指定存储位置（memory 或 calldata）。memory 是可读写的，适合需要修改参数值的场景。
    // 添加商品（仅限生产商）
    function addProduct(uint _id, string memory _name) public onlyRole(Role.Producer) {
        require(_id != 0, "Invalid ID");
        require(products[_id].id == 0, "Product ID already exists");
        products[_id] = Product(_id, _name, block.timestamp, Status.Produced, msg.sender);
        emit ProductAdded(_id, _name, msg.sender);
    }

    
    // 更新状态（根据角色限制） 增加记录状态变更时间，增加可追溯性
    function updateStatus(uint _id, Status _status) public {
        require(products[_id].id != 0, "Product does not exist");
        require(uint(_status) == uint(products[_id].productStatus) + 1, "Invalid status transition");

        if (_status == Status.Shipped) {
            require(roles[msg.sender] == Role.Transporter, "Unauthorized: Must be Transporter");
        } 
        else if (_status == Status.Delivered) {
            require(roles[msg.sender] == Role.Buyer, "Unauthorized: Must be Buyer");
            require(productBuyers[_id] == msg.sender, "Unauthorized: Not assigned Buyer");
        }

        products[_id].productStatus = _status;
        emit StatusUpdated(_id, _status, msg.sender);
    }
    

     // 查询商品信息
    function getProduct(uint _id) public returns (uint, string memory, uint, Status, address) {
        require(products[_id].id != 0, "Product does not exist");
        emit ProductQueried(_id, msg.sender);
        Product memory product = products[_id];
        return (product.id, product.name, product.productTime, product.productStatus, product.producer);
    }

    
    // 分配角色（仅限 owner）
    function assignRole(address _account, Role _role) public onlyOwner {
        require(_account != address(0), "Invalid address");
        roles[_account] = _role;
        emit RoleAssigned(_account, _role);
    }

    // 分配买方（仅限 owner）
    function assignBuyer(uint _id, address _buyer) public onlyOwner {
        require(products[_id].id != 0, "Product does not exist");
        require(_buyer != address(0), "Invalid buyer address");
        require(roles[_buyer] == Role.Buyer, "Address is not a Buyer");
        productBuyers[_id] = _buyer;
        emit BuyerAssigned(_id, _buyer);
    }

    // 转移 owner 权限
    function transferOwnership(address _newOwner) public onlyOwner {
        require(_newOwner != address(0), "Invalid new owner");
        owner = _newOwner;
    }
}
