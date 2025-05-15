//SPDX-License-Identifider:UNLICENSE

pragma solidity ^0.8.0;
contract ProductRegistry{
    enum Status {Produced,Shipped,Delivered}
    struct Product
    {
        uint id;
        string name;
        uint productTime;
        Status productStatus;
    }

    mapping(uint => Product) public products;

    // 为什么用 memory？
    // 效率：字符串（如 string）是动态大小的数据类型，直接操作 storage 中的字符串会非常昂贵（需要多次读写区块链）。使用 memory 可以先在内存中处理字符串，减少 gas 消耗。
    // 临时性：_name 只在函数执行时需要，声明为 memory 确保它不会占用区块链的持久存储空间。
    // 默认行为：对于复杂数据类型（如 string、array、struct）作为函数参数时，Solidity 要求显式指定存储位置（memory 或 calldata）。memory 是可读写的，适合需要修改参数值的场景。
    function addProduct(uint _id, string memory _name) public 
    {
        products[_id] = Product(_id, _name, block.timestamp,Status.Produced);
    }

    function updataStatus(uint _id , Status _status) public
    {
        Product storage p = products[_id];
        require(uint(_status)==uint(p.status)+1,"Invalid status");//正向递增
        p.status =_status;
    }

    //数据查询 记录查询id与查询者
    event ProductQueried(uint _id, address querier);

    function getProduct(uint _id) public view returns (uint, string memory, Status) 
    {
        require(products[_id].id != 0, "Product does not exist");//判断 输入的_id 是否存在
        Product memory _product = products[_id];
        emit ProductQueried(_id, msg.sender);//记录查询id与查询者
        return (_product.id, _product.name, _product.productStatus);
    }

    //权限控制
    address public owner;
    modifier onlyOwner()
    {
        require(msg.sender == owner,"Unauthorized");
        _;
    }
}