// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract ProductRegistry {
    // Status enum
    enum Status { Produced, Ordered, Shipped, Delivered }

    // Role enum
    enum Role { None, Producer, Transporter, Buyer }

    // Role information struct
    struct RoleInfo {
        Role role;
        string name; // Role name (e.g., "ABC Company")
    }

    // Status information struct
    struct StatusInfo {
        Status status;
        uint timestamp;
        string remark; // Status remark
        address updater; // Operator address
    }

    // Product struct
    struct Product {
        uint id;
        string name;
        uint productTime;
        Status currentStatus; // Current status
        StatusInfo[] statusChangeHistory; // Status change history
        address producer;
        address buyerAddress; // Buyer address
    }

    // Product storage
    mapping(uint => Product) public products;
    // Role information storage
    mapping(address => RoleInfo) public roles;
    // Buyer mapping (for compatibility, optional)
    mapping(uint => address) public productBuyers;

    // Contract owner
    address public owner;

    // Events
    event ProductAdded(uint indexed id, string name, address indexed producer);
    event StatusUpdated(uint indexed id, Status status, string remark, address indexed updater);
    event ProductQueried(uint indexed id, address indexed querier);
    event RoleAssigned(address indexed account, Role role, string name);
    event ProductBought(uint indexed id, address indexed buyer);
    event ProductReceived(uint indexed id, address indexed buyer);

    // Constructor: Initialize owner
    constructor() {
        owner = msg.sender;
    }

    // Modifier: Restrict to specific role
    modifier onlyRole(Role _role) {
        require(roles[msg.sender].role == _role, "Unauthorized: Invalid role");
        _;
    }

    // Modifier: Restrict to owner
    modifier onlyOwner() {
        require(msg.sender == owner, "Unauthorized: Not owner");
        _;
    }

    // Convert enum to string
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

    // Register as Buyer
    function registerAsBuyer(string calldata _name) external {
        require(roles[msg.sender].role == Role.None, "Already assigned a role");
        require(bytes(_name).length > 0, "Name cannot be empty");
        roles[msg.sender] = RoleInfo(Role.Buyer, _name);
        emit RoleAssigned(msg.sender, Role.Buyer, _name);
    }

    // Get current user role
    function getRole() external view returns (uint roleValue, string memory roleName, string memory name) {
        RoleInfo memory roleInfo = roles[msg.sender];
        return (uint(roleInfo.role), roleToString(roleInfo.role), roleInfo.name);
    }
    
    function getRoleByAddress(address _account) external view returns (uint roleValue, string memory roleName, string memory name) {
        RoleInfo memory roleInfo = roles[_account];
        return (uint(roleInfo.role), roleToString(roleInfo.role), roleInfo.name);
    }
    // Add product (Producer only)
    function addProduct(uint _id, string calldata _name) external onlyRole(Role.Producer) {
        require(_id != 0, "Invalid ID");
        require(products[_id].id == 0, "Product ID already exists");

        // Initialize Product struct
        Product storage product = products[_id];
        product.id = _id;
        product.name = _name;
        product.productTime = block.timestamp;
        product.currentStatus = Status.Produced;
        product.producer = msg.sender;
        product.buyerAddress = address(0);

        // Add initial status
        product.statusChangeHistory.push(StatusInfo({
            status: Status.Produced,
            timestamp: block.timestamp,
            remark: "Product created",
            updater: msg.sender
        }));
        emit ProductAdded(_id, _name, msg.sender);
    }

    // Update status (Transporter or Buyer)
    function updateStatus(uint _id, Status _status, string calldata _remark) external {
        require(products[_id].id != 0, "Product does not exist");
        require(uint(_status) == uint(products[_id].currentStatus) + 1, "Invalid status transition");
        require(_status == Status.Shipped, "Use receiveProduct for Delivered status");

        require(roles[msg.sender].role == Role.Transporter, "Unauthorized: Must be Transporter");

        products[_id].currentStatus = _status;
        products[_id].statusChangeHistory.push(StatusInfo({
            status: _status,
            timestamp: block.timestamp,
            remark: _remark,
            updater: msg.sender
        }));
        emit StatusUpdated(_id, _status, _remark, msg.sender);
    }

    // Receive product (Buyer only)
    function receiveProduct(uint _id, string calldata _remark) external onlyRole(Role.Buyer) {
        require(products[_id].id != 0, "Product does not exist");
        require(products[_id].currentStatus == Status.Shipped, "Product must be in Shipped status");
        require(products[_id].buyerAddress == msg.sender, "Unauthorized: Not the assigned buyer");

        products[_id].currentStatus = Status.Delivered;
        products[_id].statusChangeHistory.push(StatusInfo({
            status: Status.Delivered,
            timestamp: block.timestamp,
            remark: _remark,
            updater: msg.sender
        }));
        emit ProductReceived(_id, msg.sender);
        emit StatusUpdated(_id, Status.Delivered, _remark, msg.sender);
    }

    // Get product information
    function getProduct(uint _id) external returns (
        uint id,
        string memory name,
        uint productTime,
        uint currentStatusValue,
        string memory currentStatusName,
        StatusInfo[] memory statusChangeHistory,
        address producer,
        address buyerAddress
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
            product.producer,
            product.buyerAddress
        );
    }

    // Assign role (Owner only)
    function assignRole(address _account, Role _role, string calldata _name) external onlyOwner {
        require(_account != address(0), "Invalid address");
        require(_role != Role.Buyer, "Use registerAsBuyer for Buyer role");
        require(bytes(_name).length > 0, "Name cannot be empty");
        roles[_account] = RoleInfo(_role, _name);
        emit RoleAssigned(_account, _role, _name);
    }

    // Buy product (Buyer only)
    function buyProduct(uint _id) external onlyRole(Role.Buyer) {
        require(products[_id].id != 0, "Product does not exist");
        require(products[_id].buyerAddress == address(0), "Product already bought");
        require(products[_id].currentStatus == Status.Produced, "Product not available for purchase");

        products[_id].buyerAddress = msg.sender;
        productBuyers[_id] = msg.sender; // Maintain compatibility
        products[_id].currentStatus = Status.Ordered;
        products[_id].statusChangeHistory.push(StatusInfo({
            status: Status.Ordered,
            timestamp: block.timestamp,
            remark: "Product ordered",
            updater: msg.sender
        }));
        emit ProductBought(_id, msg.sender);
        emit StatusUpdated(_id, Status.Ordered, "Product ordered", msg.sender);
    }

    // Transfer ownership
    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "Invalid new owner");
        owner = _newOwner;
    }
}
