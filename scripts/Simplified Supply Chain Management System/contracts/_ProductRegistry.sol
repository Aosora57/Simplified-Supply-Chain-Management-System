// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract ProductRegistry {
    // 状态枚举
    enum Status { Produced, Ordered, Shipped, Delivered }

    // 角色枚举
    enum Role { None, Producer, Transporter, Buyer }

    // 角色信息结构体
    struct RoleInfo {
        Role role;
        string name; // 角色名字（如 "ABC公司"）
    }

    // 状态信息结构体
    struct StatusInfo {
        Status status;
        uint timestamp;
        string remark; // 状态备注
        address updater; // 操作人地址
    }

    // 商品结构体
    struct Product {
        uint id;
        string name;
        uint productTime;
        Status currentStatus; // 当前状态
        StatusInfo[] statusChangeHistory; // 状态变更历史
        address producer;
    }

    // 存储商品
    mapping(uint => Product) public products;
    // 存储地址的角色信息
    mapping(address => RoleInfo) public roles;
    // 存储产品对应的买方
    mapping(uint => address) public productBuyers;

    // 权限控制：合约拥有者
    address public owner;

    // 事件定义
    event ProductAdded(uint indexed id, string name, address indexed producer);
    event StatusUpdated(uint indexed id, Status status, string remark, address indexed updater);
    event ProductQueried(uint indexed id, address indexed querier);
    event RoleAssigned(address indexed account, Role role, string name);
    event ProductBought(uint indexed id, address indexed buyer);

    // 构造函数：初始化 owner
    constructor() {
        owner = msg.sender;
    }

    // 修饰符：仅限特定角色
    modifier onlyRole(Role _role) {
        require(roles[msg.sender].role == _role, "Unauthorized: Invalid role");
        _;
    }

    // 修饰符：仅限 owner
    modifier onlyOwner() {
        require(msg.sender == owner, "Unauthorized: Not owner");
        _;
    }

    // 将枚举值转换为字符串
    function statusToString(Status _status) internal pure returns (string memory) {
        if (_status == Status.Produced) return "Produced";
        if (_status == Status.Ordered) return "Ordered";
        if (_status == Status.Shipped) return "Shipped";
        if (_status == Status.Delivered) return "Delivered";
        revert("Invalid status");
    }

    function roleToString(Role _role) internal pure returns (string memory) {
        if (_role == Role.None) return "None";
        if (_role == Role.Producer) return "Producer";
        if (_role == Role.Transporter) return "Transporter";
        if (_role == Role.Buyer) return "Buyer";
        revert("Invalid role");
    }

    // 允许用户将自己指定为 Buyer
    function registerAsBuyer(string calldata _name) external {
        require(roles[msg.sender].role == Role.None, "Already assigned a role");
        require(bytes(_name).length > 0, "Name cannot be empty");
        roles[msg.sender] = RoleInfo(Role.Buyer, _name);
        emit RoleAssigned(msg.sender, Role.Buyer, _name);
    }

    // 查询当前用户角色
    function getRole() external view returns (uint roleValue, string memory roleName, string memory name) {
        RoleInfo memory roleInfo = roles[msg.sender];
        return (uint(roleInfo.role), roleToString(roleInfo.role), roleInfo.name);
    }

    // 添加商品（仅限生产商）
    function addProduct(uint _id, string calldata _name) external onlyRole(Role.Producer) {
        require(_id != 0, "Invalid ID");
        require(products[_id].id == 0, "Product ID already exists");

        // 初始化 Product 结构体
        Product storage product = products[_id];
        product.id = _id;
        product.name = _name;
        product.productTime = block.timestamp;
        product.currentStatus = Status.Produced;
        product.producer = msg.sender;

        // 添加初始状态
        product.statusChangeHistory.push(StatusInfo({
            status: Status.Produced,
            timestamp: block.timestamp,
            remark: "产品创建",
            updater: msg.sender
        }));
        emit ProductAdded(_id, _name, msg.sender);
    }

    // 更新状态（根据角色限制）
    function updateStatus(uint _id, Status _status, string calldata _remark) external {
        require(products[_id].id != 0, "Product does not exist");
        require(uint(_status) == uint(products[_id].currentStatus) + 1, "Invalid status transition");

        if (_status == Status.Shipped) {
            require(roles[msg.sender].role == Role.Transporter, "Unauthorized: Must be Transporter");
        } else if (_status == Status.Delivered) {
            require(roles[msg.sender].role == Role.Buyer, "Unauthorized: Must be Buyer");
            require(productBuyers[_id] == msg.sender, "Unauthorized: Not assigned Buyer");
        } else {
            revert("Invalid status for updateStatus");
        }

        products[_id].currentStatus = _status;
        products[_id].statusChangeHistory.push(StatusInfo({
            status: _status,
            timestamp: block.timestamp,
            remark: _remark,
            updater: msg.sender
        }));
        emit StatusUpdated(_id, _status, _remark, msg.sender);
    }

    // 查询商品信息
    function getProduct(uint _id) external returns (
        uint id,
        string memory name,
        uint productTime,
        uint currentStatusValue,
        string memory currentStatusName,
        StatusInfo[] memory statusChangeHistory,
        address producer
    ) {
        require(products[_id].id != 0, "Product does not exist");
        emit ProductQueried(_id, msg.sender);
        Product storage product = products[_id];
        return (
            product.id,
            product.name,
            product.productTime,
            uint(product.currentStatus),
            statusToString(product.currentStatus),
            product.statusChangeHistory,
            product.producer
        );
    }

    // 分配角色（仅限 owner）
    function assignRole(address _account, Role _role, string calldata _name) external onlyOwner {
        require(_account != address(0), "Invalid address");
        require(_role != Role.Buyer, "Use registerAsBuyer for Buyer role");
        require(bytes(_name).length > 0, "Name cannot be empty");
        roles[_account] = RoleInfo(_role, _name);
        emit RoleAssigned(_account, _role, _name);
    }

    // 买家购买产品
    function buyProduct(uint _id) external onlyRole(Role.Buyer) {
        require(products[_id].id != 0, "Product does not exist");
        require(productBuyers[_id] == address(0), "Product already bought");
        require(products[_id].currentStatus == Status.Produced, "Product not available for purchase");

        productBuyers[_id] = msg.sender;
        products[_id].currentStatus = Status.Ordered;
        products[_id].statusChangeHistory.push(StatusInfo({
            status: Status.Ordered,
            timestamp: block.timestamp,
            remark: "产品已下单",
            updater: msg.sender
        }));
        emit ProductBought(_id, msg.sender);
        emit StatusUpdated(_id, Status.Ordered, "产品已下单", msg.sender);
    }

    // 转移 owner 权限
    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "Invalid new owner");
        owner = _newOwner;
    }
}
