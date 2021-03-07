pragma solidity ^0.5.9;

contract KYC {

  
    address admin;
    
    /*
    Struct for a customer
     */
    struct Customer {
        string userName;   //unique
        string data_hash;  //unique
        uint rating;	    //stores rating in percentage value
        uint8 upvotes;
        address bank;
    }

    /*
    Struct for a Bank
     */
    struct Bank {
        address ethAddress;   //unique  
        string bankName;
        string regNumber;     //unique   
        uint rating;         //stores rating in percentage value
        uint8 upvotes;
        uint8 kycCount;
    }

    /*
    Struct for a KYC Request
     */
    struct KYCRequest {
        string userName;     
        string data_hash;  //unique
        address bank;
        bool isAllowed;
    }

    /*
    Mapping a customer's username to the Customer struct
    We also keep an array of all keys of the mapping to be able to loop through them when required.
     */
    mapping(string => Customer) customers;
    string[] customerNames;
    
    /*
    Mapping a customer's username to its password;
    */
    mapping(string => bytes32) private customerPasswords;
    
    /*
    Mapping a verified customer's username to the Customer struct
    We also keep an array of all keys of the mapping to be able to loop through them when required.
     */
    mapping(string => Customer) verifiedCustomers;
    string[] verifiedCustomerNames;

    /*
    Mapping a bank's address to the Bank Struct
    We also keep an array of all keys of the mapping to be able to loop through them when required.
     */
    mapping(address => Bank) banks;
    address[] bankAddresses;

    /*
    Mapping a customer's Data Hash to KYC request captured for that customer.
    This mapping is used to keep track of every kycRequest initiated for every customer by a bank.
     */
    mapping(string => KYCRequest) kycRequests;
    string[] private customerDataList;

    /*
    Mapping a customer's user name with a bank's address
    This mapping is used to keep track of every upvote given by a bank to a customer
     */
    mapping(string => mapping(address => uint256)) customerUpvotes;
    
      /*
    Mapping a bank's address with the address of the bank who upvoted
    This mapping is used to keep track of every upvote given by a bank to other bank
     */
    mapping(address => mapping(address => uint256)) bankUpvotes;

    /**
     * Constructor of the contract.
     * We save the contract's admin as the account which deployed this contract.
     */
    constructor() public {
        admin = msg.sender;
    }

    /**
     * Record a new KYC request on behalf of a customer
     * The sender of message call is the bank itself
     * @param  {string} _userName The name of the customer for whom KYC is to be done
     * @param  {address} _bankEthAddress The ethAddress of the bank issuing this request
     * @return {bool}        True if this function execution was successful
     */
    function addKycRequest(string memory _userName, string memory _customerData) public returns (uint8) {
        // Check that the user's KYC has not been done before, the Bank is a valid bank and it is allowed to perform KYC.
        require(kycRequests[_customerData].bank == address(0), "This user already has a KYC request with same data in process.");
        //bytes memory uname = new bytes(bytes(_userName));
        // Save the timestamp for this KYC request.
        kycRequests[_customerData].data_hash = _customerData;
        kycRequests[_customerData].userName = _userName;
        kycRequests[_customerData].bank = msg.sender;
        //set isAllowed flag to false if the bank rating is less than 0.5 (50%) and true otherwise.
        if(banks[msg.sender].rating <= (0.5*100)){
        	kycRequests[_customerData].isAllowed = false;
        } else{
        	kycRequests[_customerData].isAllowed = true;
        }
        customerDataList.push(_customerData);
        banks[msg.sender].kycCount++;
        
        return 1;
    }

    /**
     * Add a new customer
     * @param {string} _userName Name of the customer to be added
     * @param {string} _hash Hash of the customer's ID submitted for KYC
     */
    function addCustomer(string memory _userName, string memory _customerData) public returns (uint8) {	
        require(customers[_userName].bank == address(0), "This customer is already present, please call modifyCustomer to edit the customer data");
        require(kycRequests[_customerData].isAllowed, "The KYC request for this customer was not added by a trusted bank");
        customers[_userName].userName = _userName;
        customers[_userName].data_hash = _customerData;
        customers[_userName].bank = msg.sender;
        customers[_userName].rating = 0;
        customers[_userName].upvotes = 0;
        customerNames.push(_userName);
        return 1;
    }

    /**
     * Remove KYC request
     * @param  {string} _userName Name of the customer
     * @return {uint8}         A 0 indicates failure, 1 indicates success
     */
    function removeKYCRequest(string memory _userName) public returns (uint8) {
        uint8 k=0;
        for (uint256 i = 0; i< customerDataList.length; i++) {
            if (stringsEquals(kycRequests[customerDataList[i]].userName,_userName)) {
                delete kycRequests[customerDataList[i]];
                //Remove the given customer user name also from the customerNames Array
                for(uint j = i+1;j < customerDataList.length;j++) 
                { 
                    customerDataList[j-1] = customerDataList[j];
                }
                customerDataList.length --;
                k=1;
            }
        }
        return k; // 0 is returned if no request with the input username is found.
    }

    /**
     * Remove customer information
     * @param  {string} _userName Name of the customer
     * @return {uint8}         A 0 indicates failure, 1 indicates success
     */
    function removeCustomer(string memory _userName) public returns (uint8) {
    	     require(customers[_userName].bank != address(0), "This customer is not present");
            for(uint i = 0;i < customerNames.length;i++) 
            { 
                if(stringsEquals(customerNames[i],_userName))
                {
                    delete customers[_userName];
                    //Remove the given customer user name also from the customerNames Array
                    for(uint j = i+1;j < customerNames.length;j++) 
                    {
                        customerNames[j-1] = customerNames[j];
                    }
                    customerNames.length--;
                    return 1;
                }
                
            }
            return 0;
    }

    /**
     * Edit customer information
     * @param  {public} _userName Name of the customer
     * @param  {public} _hash New hash of the updated ID provided by the customer
     * @return {uint8}         A 0 indicates failure, 1 indicates success
     */
    function modifyCustomer(string memory _userName, string memory _newcustomerData) public returns (uint8) {
     	require(customers[_userName].bank != address(0), "This customer is not present");
        for(uint i = 0;i < customerNames.length;i++) 
        { 
            if(stringsEquals(customerNames[i],_userName))
            {
            		customers[_userName].data_hash = _newcustomerData;
            		customers[_userName].bank = msg.sender;
                            
                	//Iterate over verified Customer Names list to checkf if the user is already verified
                	//If the user is already verified, remove it from the verified final list and change the upvotes and rating 			//component of the customer in customer list to "0"
        		for(uint j = 0;j < verifiedCustomerNames.length;j++) { 
        			if(stringsEquals(verifiedCustomerNames[j],_userName)) {
        				delete verifiedCustomers[_userName];
        				for(uint k = j+1;k < verifiedCustomerNames.length;k++) {
        					verifiedCustomerNames[k-1] = verifiedCustomerNames[k];
        				}
        				verifiedCustomerNames.length--;
        				customers[_userName].rating = 0;
        				customers[_userName].upvotes = 0;
        			}
		        }
		        return 1;
            }
            
        }
        return 0;
    }

    /**
     * View customer information
     * @param  {public} _userName Name of the customerzz
     * @param  {public} _password Password of the customer
     * @return {string} 	   The hash of the customer data
     */
    function viewCustomer(string memory _userName, string memory _password) public view returns (string memory) {
     	require(customers[_userName].bank != address(0), "This customer is not present");
    	require(customerPasswords[_userName] == 0 || customerPasswords[_userName] == sha256(bytes(_password)), "Incorrect password");
    
    	return customers[_userName].data_hash;
    }

    /**
     * Add a new upvote from a bank
     * @param {public} _userName Name of the customer to be upvoted
     * @return {uint8}         A 0 indicates failure, 1 indicates success
     */
    function upvoteCustomer(string memory _userName) public returns (uint8) {
    	require(customerUpvotes[_userName][msg.sender] == 0, "The bank has already voted for the same customer");
    	
    	
        for(uint8 i = 0;i < customerNames.length;i++) 
            { 
                if(stringsEquals(customerNames[i],_userName))
                {
                
                    customers[_userName].upvotes++;
                    
                    //The rating is calculated as the number of upvotes for the customer/total number of banks.
                    customers[_userName].rating = (uint(customers[_userName].upvotes) * uint(100)) / uint(bankAddresses.length);
                    
                    customerUpvotes[_userName][msg.sender] = now;//storing the timestamp when vote was casted
                    
                    //If rating is more than 0.5, then add the customer to the verified final customer list.
                    if(verifiedCustomers[_userName].bank == address(0) && customers[_userName].rating > (0.5 * 100)){
                    	verifiedCustomers[_userName].userName = customers[_userName].userName;
            			verifiedCustomers[_userName].data_hash = customers[_userName].data_hash;
            			verifiedCustomers[_userName].bank = customers[_userName].bank;
            			verifiedCustomers[_userName].rating = customers[_userName].rating;
            			verifiedCustomers[_userName].upvotes = customers[_userName].upvotes;
            			verifiedCustomerNames.push(_userName);
                    }
                    return 1;
                }
            
            }
            return 0;
        
    }
    
     /**
     * This function fetches the KYC requests for a specific bank.
     * @param  {public} bank address for which kyc requests to be fetched
     * @param {uint8}  position of kyc request list to be fetched
     * @return {kycRequest}  A Kyc request initiated by the bank which are yet to be validated.
     */
    function getBankRequests(address bank, uint8 position) public view returns (string memory, string memory, address, bool){
    
    	uint8 count=1;
    	//Iterate over the customerDataList and if the given bank has pending KYC reqeusts (isAllowed = false) and its position matches with the current count of the pending KYC list, return the KYC request details.
    	for (uint256 i = 0; i< customerDataList.length; i++) {
            if (kycRequests[customerDataList[i]].bank == bank && kycRequests[customerDataList[i]].isAllowed == false && count++ == position) {
            
            	return (kycRequests[customerDataList[i]].userName, kycRequests[customerDataList[i]].data_hash, kycRequests[customerDataList[i]].bank, kycRequests[customerDataList[i]].isAllowed);
            }
        }
        
       revert("KYC Request not found for the given position");
    }
       
    /**
     * This function is used to add and update votes for the banks.
     * @param  {public} address of the bank to be upvoted
     * @return {uint8}  A 0 indicates failure, 1 indicates success
     */
    function upvoteBanks(address bankToBeUpvoted) public returns (uint8){
        require(banks[msg.sender].ethAddress != address(0), "The message sender is not a bank");
    	require(bankUpvotes[bankToBeUpvoted][msg.sender] == 0, "The bank has already voted for the same bank before");
    	
    	 for(uint8 i = 0;i < bankAddresses.length;i++) 
         { 
                if(bankAddresses[i] == bankToBeUpvoted)
                {
                	banks[bankToBeUpvoted].upvotes++;
                	                	
                	bankUpvotes[bankToBeUpvoted][msg.sender]=now;//storing the timestamp when vote was casted
                	
                	//The bank rating is calculated as the number of upvotes for the bank/total number of banks.
                    	banks[bankToBeUpvoted].rating = (uint(banks[bankToBeUpvoted].upvotes) * uint(100)) / uint(bankAddresses.length);
                    	return 1;
                }
         }
    	
        return 0;
    }
    
     /**
     * This function is used to fetch customer rating from the smart contract. 
     * @param  {public}  _userName Name of the customer
     * @return {uint8}  Rating of the customer
     */
     function getCustomerRating(string memory _userName) public view returns(uint){
     	require(customers[_userName].bank != address(0), "This customer does not exist");
     	return customers[_userName].rating;
     }

     /**
     * This function is used to fetch bank rating from the smart contract. 
     * @param  {public}  _userName Name of the customer
     * @return {uint8}  Rating of the customer
     */
     function getBankRating(address  _bankAddress) public view returns(uint){
     	require(banks[_bankAddress].ethAddress != address(0), "This bank does not exist");
     	return banks[_bankAddress].rating;
     }
     
     /**
     * This function is used to fetch the bank details which made the last changes to the customer data.
     * @param  {public} _userName Name of the customer
     * @return {address} Bank address as address is returned 
     */
     function getAccessHistory(string memory _userName) public view returns(address){
    	require(customers[_userName].bank != address(0), "This customer does not exist");
    	return customers[_userName].bank;
    }

     
     /**
     * This function is used to set a password for customer data.
     * @param  {public} _userName Name of the customer
     * @param  {public} _password Password of the customer
     * @return {bool} 	 A boolean result is returned which determines if the password for the customer has been successfully updated.
     */
    function setPassword(string memory _userName, string memory _password) public returns (bool) {
        require(customers[_userName].bank != address(0), "This customer does not exist");
    	customerPasswords[_userName] = sha256(bytes(_password));
    	return true;
    }
    
    /**
     * This function is used to fetch the bank details.
     * @param  {public} _userName Name of the customer
     * @return {Bank}         The bank struct as an object
     */
    function getBankDetails(address _bankAddress) public view returns (string memory) {
  	    require(banks[_bankAddress].ethAddress != address(0), "This bank address is not present");
            return (banks[_bankAddress].bankName);
    }

    /**
     * This function is used by the admin to add a bank to the KYC Contract.
     * @param {string} _userName Name of the bank to be added
     * @param {address} _bankAddress address of the bank to be added
     * @param {string} _regNumber Registration number of the bank to be added
     * @return {uint8}  A 0 indicates failure, 1 indicates success
     */
    function addBank(string memory _bankName, address _bankAddress, string memory _regNumber) public onlyAdmin returns (uint8) {	
        require(banks[_bankAddress].ethAddress == address(0), "This bank is already present");
        banks[_bankAddress].bankName = _bankName;
        banks[_bankAddress].ethAddress = _bankAddress;
        banks[_bankAddress].regNumber = _regNumber;
        banks[_bankAddress].rating = 0;
        banks[_bankAddress].upvotes = 0;
        banks[_bankAddress].kycCount = 0;
        bankAddresses.push(_bankAddress);
        return 1;
    }
    
    /**
     * This function is used by the admin to remove a bank from the KYC Contract.
     * @param {address} _bankAddress address of the bank to be added
     * @return {uint8}  A 0 indicates failure, 1 indicates success
     */
    function removeBank(address _bankAddress) public onlyAdmin returns (uint8){	
        require(banks[_bankAddress].ethAddress != address(0), "This bank is not present");
         for(uint i = 0;i < bankAddresses.length;i++) 
            { 
                if(bankAddresses[i] == _bankAddress)
                {
                    delete banks[_bankAddress];
                    for(uint j = i+1;j < bankAddresses.length;j++) 
                    {
                        bankAddresses[j-1] = bankAddresses[j];
                    }
                    bankAddresses.length--;
                    return 1;
                }
                
            }
        return 0;
    }
    
     /**
     * This is an internal function used to compare two string values.
     * @param - String a and String b are passed as Parameters
     * @return  {bool} This function returns true if strings are matched and false if the strings are not matching
     */
    function stringsEquals(string storage _a, string memory _b) internal view returns (bool) {
        bytes storage a = bytes(_a);
        bytes memory b = bytes(_b); 
        if (a.length != b.length)
            return false;
        // @todo unroll this loop
        for (uint i = 0; i < a.length; i ++)
        {
            if (a[i] != b[i])
                return false;
        }
        return true;
    }
    
    // modifier to allow only admin to perform the given operation
    modifier onlyAdmin {
        require(msg.sender == admin, "Only the admin can add a bank to the KYC Contract");
        _;
    }

}
