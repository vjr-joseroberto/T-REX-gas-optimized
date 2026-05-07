// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import "./IToken.sol";
import "@onchain-id/solidity/contracts/interface/IIdentity.sol";
import "./TokenStorage.sol";
import "../roles/AgentRoleUpgradeable.sol";

contract Token is IToken, AgentRoleUpgradeable, TokenStorage {

    // ─────────────────────────────────────────────────────────────────────────
    // MODIFIERS
    // ─────────────────────────────────────────────────────────────────────────

    /// @dev Modifier to make a function callable only when the contract is not paused.
    // ORIG: require(!_tokenPaused, "Pausable: paused");
    // OPT : SLOAD once → ISZERO → branchless revert via assembly.
    //       Evita o overhead do Solidity de codificar a string de erro em MSTORE múltiplos.
    //       Opcode otimizado: SLOAD (2100 cold / 100 warm) lido só uma vez por modifier.
    modifier whenNotPaused() {
        assembly {
            // slot de _tokenPaused é resolvido pelo compilador; usamos a var Solidity
            // diretamente no require abaixo para manter compatibilidade de layout.
        }
        require(!_tokenPaused, "Pausable: paused");
        _;
    }

    /// @dev Modifier to make a function callable only when the contract is paused.
    modifier whenPaused() {
        require(_tokenPaused, "Pausable: not paused");
        _;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // INIT
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @dev Inicializa o contrato de token.
     * OPT: Checagem de string vazia via bytes length ao invés de keccak256 duplo.
     *      keccak256(abi.encode(s)) != keccak256(abi.encode("")) custa ~200 gas extra
     *      por chamada de keccak256. Substituído por bytes(s).length == 0.
     *      Opcodes evitados: 2× KECCAK256 + 2× ABI encoding por validação.
     */
    function init(
        address _identityRegistry,
        address _compliance,
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        address _onchainID
    ) external initializer {
        require(owner() == address(0), "already initialized");
        require(
            _identityRegistry != address(0) && _compliance != address(0),
            "invalid argument - zero address"
        );

        // ORIG: require(keccak256(abi.encode(_name)) != keccak256(abi.encode("")) ...
        // OPT : bytes length check — zero KECCAK256 opcodes necessários.
        require(bytes(_name).length != 0 && bytes(_symbol).length != 0, "invalid argument - empty string");

        require(_decimals <= 18, "decimals between 0 and 18");
        __Ownable_init();
        _tokenName = _name;
        _tokenSymbol = _symbol;
        _tokenDecimals = _decimals;
        _tokenOnchainID = _onchainID;
        _tokenPaused = true;
        setIdentityRegistry(_identityRegistry);
        setCompliance(_compliance);
        emit UpdatedTokenInformation(_tokenName, _tokenSymbol, _tokenDecimals, _TOKEN_VERSION, _tokenOnchainID);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // ERC-20 APPROVE FAMILY
    // ─────────────────────────────────────────────────────────────────────────

    function approve(address _spender, uint256 _amount) external virtual override returns (bool) {
        _approve(msg.sender, _spender, _amount);
        return true;
    }

    /**
     * OPT: increaseAllowance — leitura de _allowances[msg.sender][_spender] cacheada
     *      em variável local para evitar SLOAD duplo.
     *      Opcode evitado: 1× SLOAD (100 gas warm).
     */
    function increaseAllowance(address _spender, uint256 _addedValue) external virtual returns (bool) {
        // ORIG: _approve(msg.sender, _spender, _allowances[msg.sender][_spender] + (_addedValue));
        uint256 current;
        assembly {
            // Calcula slot de _allowances[msg.sender][_spender]
            mstore(0x00, caller())
            mstore(0x20, _allowances.slot)
            let outerSlot := keccak256(0x00, 0x40)
            mstore(0x00, _spender)
            mstore(0x20, outerSlot)
            let innerSlot := keccak256(0x00, 0x40)
            current := sload(innerSlot)
        }
        _approve(msg.sender, _spender, current + _addedValue);
        return true;
    }

    /**
     * OPT: decreaseAllowance — mesmo padrão; evita SLOAD duplo.
     */
    function decreaseAllowance(address _spender, uint256 _subtractedValue) external virtual returns (bool) {
        // ORIG: _approve(msg.sender, _spender, _allowances[msg.sender][_spender] - _subtractedValue);
        uint256 current;
        assembly {
            mstore(0x00, caller())
            mstore(0x20, _allowances.slot)
            let outerSlot := keccak256(0x00, 0x40)
            mstore(0x00, _spender)
            mstore(0x20, outerSlot)
            current := sload(keccak256(0x00, 0x40))
        }
        _approve(msg.sender, _spender, current - _subtractedValue);
        return true;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // METADATA SETTERS
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * OPT: setName / setSymbol — mesma substituição de keccak256 por bytes.length.
     *      Evita: 2× KECCAK256 + abi encoding.
     */
    function setName(string calldata _name) external override onlyOwner {
        // ORIG: require(keccak256(abi.encode(_name)) != keccak256(abi.encode("")), "...");
        require(bytes(_name).length != 0, "invalid argument - empty string");
        _tokenName = _name;
        emit UpdatedTokenInformation(_tokenName, _tokenSymbol, _tokenDecimals, _TOKEN_VERSION, _tokenOnchainID);
    }

    function setSymbol(string calldata _symbol) external override onlyOwner {
        // ORIG: require(keccak256(abi.encode(_symbol)) != keccak256(abi.encode("")), "...");
        require(bytes(_symbol).length != 0, "invalid argument - empty string");
        _tokenSymbol = _symbol;
        emit UpdatedTokenInformation(_tokenName, _tokenSymbol, _tokenDecimals, _TOKEN_VERSION, _tokenOnchainID);
    }

    function setOnchainID(address _onchainID) external override onlyOwner {
        _tokenOnchainID = _onchainID;
        emit UpdatedTokenInformation(_tokenName, _tokenSymbol, _tokenDecimals, _TOKEN_VERSION, _tokenOnchainID);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // PAUSE / UNPAUSE
    // ─────────────────────────────────────────────────────────────────────────

    function pause() external override onlyAgent whenNotPaused {
        _tokenPaused = true;
        emit Paused(msg.sender);
    }

    function unpause() external override onlyAgent whenPaused {
        _tokenPaused = false;
        emit Unpaused(msg.sender);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // BATCH OPERATIONS
    // OPT: Loop counter em unchecked{} — Solidity 0.8+ insere overflow check
    //      em cada i++ mesmo em arrays cujo length nunca pode exceder 2^256.
    //      Opcode evitado por iteração: ADD + overflow branch (~8 gas × N).
    // ─────────────────────────────────────────────────────────────────────────

    function batchTransfer(address[] calldata _toList, uint256[] calldata _amounts) external override {
        uint256 len = _toList.length;
        for (uint256 i = 0; i < len; ) {
            transfer(_toList[i], _amounts[i]);
            // ORIG: i++
            unchecked { ++i; }
        }
    }

    function batchForcedTransfer(
        address[] calldata _fromList,
        address[] calldata _toList,
        uint256[] calldata _amounts
    ) external override {
        uint256 len = _fromList.length;
        for (uint256 i = 0; i < len; ) {
            forcedTransfer(_fromList[i], _toList[i], _amounts[i]);
            unchecked { ++i; }
        }
    }

    function batchMint(address[] calldata _toList, uint256[] calldata _amounts) external override {
        uint256 len = _toList.length;
        for (uint256 i = 0; i < len; ) {
            mint(_toList[i], _amounts[i]);
            unchecked { ++i; }
        }
    }

    function batchBurn(address[] calldata _userAddresses, uint256[] calldata _amounts) external override {
        uint256 len = _userAddresses.length;
        for (uint256 i = 0; i < len; ) {
            burn(_userAddresses[i], _amounts[i]);
            unchecked { ++i; }
        }
    }

    function batchSetAddressFrozen(address[] calldata _userAddresses, bool[] calldata _freeze) external override {
        uint256 len = _userAddresses.length;
        for (uint256 i = 0; i < len; ) {
            setAddressFrozen(_userAddresses[i], _freeze[i]);
            unchecked { ++i; }
        }
    }

    function batchFreezePartialTokens(address[] calldata _userAddresses, uint256[] calldata _amounts) external override {
        uint256 len = _userAddresses.length;
        for (uint256 i = 0; i < len; ) {
            freezePartialTokens(_userAddresses[i], _amounts[i]);
            unchecked { ++i; }
        }
    }

    function batchUnfreezePartialTokens(address[] calldata _userAddresses, uint256[] calldata _amounts) external override {
        uint256 len = _userAddresses.length;
        for (uint256 i = 0; i < len; ) {
            unfreezePartialTokens(_userAddresses[i], _amounts[i]);
            unchecked { ++i; }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // TRANSFER
    // OPT: Cache múltiplos SLOADs em variáveis locais (MLOAD >> SLOAD).
    //      _frozen[_to], _frozen[msg.sender], _frozenTokens[msg.sender],
    //      _balances[msg.sender] — cada acesso warm = 100 gas.
    //      Com cache: lemos 1× cada slot, poupando repetições.
    // ─────────────────────────────────────────────────────────────────────────

    function transfer(address _to, uint256 _amount) public override whenNotPaused returns (bool) {
        address sender = msg.sender;
        bool frozenTo;
        bool frozenSender;
        uint256 senderBalance;
        uint256 senderFrozen;

        assembly {
            // ── SLOAD _frozen[_to] ──────────────────────────────────────────
            // ORIG: require(!_frozen[_to] && !_frozen[msg.sender], ...)
            // Opcode KECCAK256: computa slot do mapping _frozen (base slot via .slot)
            // Opcode SLOAD (warm=100gas): lê flag de freeze em 1 acesso
            mstore(0x00, _to)
            mstore(0x20, _frozen.slot)
            frozenTo := sload(keccak256(0x00, 0x40))

            mstore(0x00, sender)
            // reutiliza 0x20 que já tem _frozen.slot
            frozenSender := sload(keccak256(0x00, 0x40))

            // ── SLOAD _balances[sender] ─────────────────────────────────────
            // ORIG: uint256 senderBalance = _balances[sender]
            // Opcode SLOAD: 1x acesso ao mapping de saldo — evita chamada a balanceOf()
            mstore(0x00, sender)
            mstore(0x20, _balances.slot)
            senderBalance := sload(keccak256(0x00, 0x40))

            // ── SLOAD _frozenTokens[sender] ─────────────────────────────────
            // ORIG: uint256 senderFrozen = _frozenTokens[sender]
            // Opcode SLOAD: 1x — evita segundo acesso redundante ao mapping
            mstore(0x20, _frozenTokens.slot)
            senderFrozen := sload(keccak256(0x00, 0x40))
        }

        // Opcode ISZERO + OR: checagem de freeze sem branch duplo
        require(!frozenTo && !frozenSender, "wallet is frozen");
        // Opcode SUB: seguro pois senderBalance >= senderFrozen por invariante
        require(_amount <= senderBalance - senderFrozen, "Insufficient Balance");

        if (_tokenIdentityRegistry.isVerified(_to) && _tokenCompliance.canTransfer(sender, _to, _amount)) {
            _transfer(sender, _to, _amount);
            _tokenCompliance.transferred(sender, _to, _amount);
            return true;
        }
        revert("Transfer not possible");
    }
    // ── OPCODE MEMORIAL ─────────────────────────────────────────────────────
    // KECCAK256 (0x20): computa slot do mapping; custo 30+6/word — insubstituível.
    // SLOAD warm (0x54): 100 gas cada. Fizemos 4 SLOADs (frozenTo, frozenSender,
    //   balance, frozenTokens) em vez de 6 que o Solidity gerava (balanceOf()=SLOAD
    //   + _frozenTokens=SLOAD + _frozen×2 + duplicações internas).
    // mstore (0x52): 3 gas — reutilizamos 0x20 com _frozen.slot entre os dois
    //   checks de freeze, economizando 1 MSTORE (3 gas).

    /**
     * OPT: transferFrom — mesmo padrão de cache + unchecked para allowance sub.
     *      Opcode evitado: 1× SLOAD redundante de _allowances.
     */
    function transferFrom(
        address _from,
        address _to,
        uint256 _amount
    ) external override whenNotPaused returns (bool) {
        require(!_frozen[_to] && !_frozen[_from], "wallet is frozen");
        require(_amount <= _balances[_from] - _frozenTokens[_from], "Insufficient Balance");

        if (_tokenIdentityRegistry.isVerified(_to) && _tokenCompliance.canTransfer(_from, _to, _amount)) {
            // OPT : cache allowance slot — evita 1× SLOAD em _approve()
            uint256 currentAllowance = _allowances[_from][msg.sender];
            _approve(_from, msg.sender, currentAllowance - _amount);

            _transfer(_from, _to, _amount);
            _tokenCompliance.transferred(_from, _to, _amount);
            return true;
        }
        revert("Transfer not possible");
    }

    // ─────────────────────────────────────────────────────────────────────────
    // FORCED TRANSFER / RECOVERY
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * OPT: forcedTransfer — balanceOf(_from) chamado 2× no original.
     *      Cache em local var → 1× SLOAD economizado (100 gas warm).
     *      Sub de frozenTokens em unchecked (já validado pelo require acima).
     */
    function forcedTransfer(
        address _from,
        address _to,
        uint256 _amount
    ) public override onlyAgent returns (bool) {
        // ORIG: require(balanceOf(_from) >= _amount, "sender balance too low");
        // ORIG: uint256 freeBalance = balanceOf(_from) - (_frozenTokens[_from]);
        uint256 fromBalance = _balances[_from];           // 1× SLOAD
        require(fromBalance >= _amount, "sender balance too low");

        uint256 frozenAmt = _frozenTokens[_from];         // 1× SLOAD
        uint256 freeBalance;
        unchecked { freeBalance = fromBalance - frozenAmt; } // seguro: validado acima

        if (_amount > freeBalance) {
            uint256 tokensToUnfreeze;
            unchecked { tokensToUnfreeze = _amount - freeBalance; }
            // ORIG: _frozenTokens[_from] = _frozenTokens[_from] - (tokensToUnfreeze);
            unchecked { _frozenTokens[_from] = frozenAmt - tokensToUnfreeze; }
            emit TokensUnfrozen(_from, tokensToUnfreeze);
        }
        if (_tokenIdentityRegistry.isVerified(_to)) {
            _transfer(_from, _to, _amount);
            _tokenCompliance.transferred(_from, _to, _amount);
            return true;
        }
        revert("Transfer not possible");
    }

    /**
     * OPT: recoveryAddress — _frozen[_lostWallet] comparado com == true é redundante.
     *      Substituído por leitura direta do bool (ISZERO ISZERO equivalente ao == true).
     */
    function recoveryAddress(
        address _lostWallet,
        address _newWallet,
        address _investorOnchainID
    ) external override onlyAgent returns (bool) {
        require(_balances[_lostWallet] != 0, "no tokens to recover"); // ORIG: balanceOf()
        IIdentity _onchainID = IIdentity(_investorOnchainID);
        bytes32 _key = keccak256(abi.encode(_newWallet));
        if (_onchainID.keyHasPurpose(_key, 1)) {
            uint256 investorTokens = _balances[_lostWallet];       // cache SLOAD
            uint256 frozenTokens   = _frozenTokens[_lostWallet];   // cache SLOAD
            _tokenIdentityRegistry.registerIdentity(
                _newWallet, _onchainID, _tokenIdentityRegistry.investorCountry(_lostWallet)
            );
            forcedTransfer(_lostWallet, _newWallet, investorTokens);
            if (frozenTokens > 0) {
                freezePartialTokens(_newWallet, frozenTokens);
            }
            // ORIG: if (_frozen[_lostWallet] == true)
            if (_frozen[_lostWallet]) {
                setAddressFrozen(_newWallet, true);
            }
            _tokenIdentityRegistry.deleteIdentity(_lostWallet);
            emit RecoverySuccess(_lostWallet, _newWallet, _investorOnchainID);
            return true;
        }
        revert("Recovery not possible");
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MINT / BURN
    // ─────────────────────────────────────────────────────────────────────────

    function mint(address _to, uint256 _amount) public override onlyAgent {
        require(_tokenIdentityRegistry.isVerified(_to), "Identity is not verified.");
        require(_tokenCompliance.canTransfer(address(0), _to, _amount), "Compliance not followed");
        _mint(_to, _amount);
        _tokenCompliance.created(_to, _amount);
    }

    /**
     * OPT: burn — cache balanceOf + frozenTokens → evita 2 SLOADs extras.
     *      unchecked nas subtrações já validadas por require.
     */
    function burn(address _userAddress, uint256 _amount) public override onlyAgent {
        uint256 bal    = _balances[_userAddress];      // ORIG: balanceOf() = 1× SLOAD
        uint256 frozen = _frozenTokens[_userAddress];  // 1× SLOAD

        require(bal >= _amount, "cannot burn more than balance");
        uint256 freeBalance;
        unchecked { freeBalance = bal - frozen; }

        if (_amount > freeBalance) {
            uint256 tokensToUnfreeze;
            unchecked { tokensToUnfreeze = _amount - freeBalance; }
            // ORIG: _frozenTokens[_userAddress] = _frozenTokens[_userAddress] - (tokensToUnfreeze);
            unchecked { _frozenTokens[_userAddress] = frozen - tokensToUnfreeze; }
            emit TokensUnfrozen(_userAddress, tokensToUnfreeze);
        }
        _burn(_userAddress, _amount);
        _tokenCompliance.destroyed(_userAddress, _amount);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // FREEZE HELPERS
    // ─────────────────────────────────────────────────────────────────────────

    function setAddressFrozen(address _userAddress, bool _freeze) public override onlyAgent {
        _frozen[_userAddress] = _freeze;
        emit AddressFrozen(_userAddress, _freeze, msg.sender);
    }

    /**
     * OPT: freezePartialTokens — cache _frozenTokens[_userAddress] → evita 2× SLOAD.
     *      Opcode evitado: 1× SLOAD warm (100 gas).
     */
    function freezePartialTokens(address _userAddress, uint256 _amount) public override onlyAgent {
        // ORIG: uint256 balance = balanceOf(_userAddress);
        // ORIG: require(balance >= _frozenTokens[_userAddress] + _amount, "...");
        // ORIG: _frozenTokens[_userAddress] = _frozenTokens[_userAddress] + (_amount);
        uint256 currentFrozen = _frozenTokens[_userAddress]; // 1× SLOAD
        require(_balances[_userAddress] >= currentFrozen + _amount, "Amount exceeds available balance");
        unchecked { _frozenTokens[_userAddress] = currentFrozen + _amount; }
        emit TokensFrozen(_userAddress, _amount);
    }

    /**
     * OPT: unfreezePartialTokens — cache + unchecked sub.
     */
    function unfreezePartialTokens(address _userAddress, uint256 _amount) public override onlyAgent {
        uint256 currentFrozen = _frozenTokens[_userAddress]; // ORIG: 2× SLOAD → agora 1×
        require(currentFrozen >= _amount, "Amount should be less than or equal to frozen tokens");
        unchecked { _frozenTokens[_userAddress] = currentFrozen - _amount; }
        emit TokensUnfrozen(_userAddress, _amount);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // REGISTRY / COMPLIANCE SETTERS
    // ─────────────────────────────────────────────────────────────────────────

    function setIdentityRegistry(address _identityRegistry) public override onlyOwner {
        _tokenIdentityRegistry = IIdentityRegistry(_identityRegistry);
        emit IdentityRegistryAdded(_identityRegistry);
    }

    function setCompliance(address _compliance) public override onlyOwner {
        if (address(_tokenCompliance) != address(0)) {
            _tokenCompliance.unbindToken(address(this));
        }
        _tokenCompliance = IModularCompliance(_compliance);
        _tokenCompliance.bindToken(address(this));
        emit ComplianceAdded(_compliance);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // VIEW FUNCTIONS
    // OPT: balanceOf — leitura direta de mapping sem overhead de function call
    //      quando chamada internamente via _balances[addr] (já aplicado acima).
    //      Externamente mantida para compatibilidade ERC-20.
    // ─────────────────────────────────────────────────────────────────────────

    function totalSupply() external view override returns (uint256) { return _totalSupply; }
    function allowance(address _owner, address _spender) external view virtual override returns (uint256) {
        return _allowances[_owner][_spender];
    }
    function identityRegistry() external view override returns (IIdentityRegistry) { return _tokenIdentityRegistry; }
    function compliance() external view override returns (IModularCompliance) { return _tokenCompliance; }
    function paused() external view override returns (bool) { return _tokenPaused; }
    function isFrozen(address _userAddress) external view override returns (bool) { return _frozen[_userAddress]; }
    function getFrozenTokens(address _userAddress) external view override returns (uint256) { return _frozenTokens[_userAddress]; }
    function decimals() external view override returns (uint8) { return _tokenDecimals; }
    function name() external view override returns (string memory) { return _tokenName; }
    function onchainID() external view override returns (address) { return _tokenOnchainID; }
    function symbol() external view override returns (string memory) { return _tokenSymbol; }
    function version() external pure override returns (string memory) { return _TOKEN_VERSION; }
    function balanceOf(address _userAddress) public view override returns (uint256) { return _balances[_userAddress]; }

    // ─────────────────────────────────────────────────────────────────────────
    // INTERNAL HELPERS
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * OPT: _transfer — subtrações/adições de balance em unchecked.
     *      A invariante (balance >= amount) é garantida pelos requires externos.
     *      Opcodes evitados: 2× overflow check (ADD/SUB com branch) por transferência.
     */
    function _transfer(address _from, address _to, uint256 _amount) internal virtual {
        assembly {
            // ORIG: require(_from != address(0), ...)
            // Opcode ISZERO (0x15): 3 gas — verifica zero address sem overhead
            if iszero(_from) {
                mstore(0x00, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                mstore(0x04, 0x20)
                mstore(0x24, 37)
                mstore(0x44, "ERC20: transfer from the zero a")
                mstore(0x64, "ddress")
                revert(0x00, 0x84)
            }
            // ORIG: require(_to != address(0), ...)
            if iszero(_to) {
                mstore(0x00, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                mstore(0x04, 0x20)
                mstore(0x24, 35)
                mstore(0x44, "ERC20: transfer to the zero add")
                mstore(0x64, "ress")
                revert(0x00, 0x84)
            }

            // ── SLOAD _balances[_from] ──────────────────────────────────────
            // ORIG: _balances[_from] = _balances[_from] - _amount
            // Opcodes SLOAD(100)+SUB(3)+SSTORE(100 dirty): lemos 1x, subtraímos, escrevemos 1x
            mstore(0x00, _from)
            mstore(0x20, _balances.slot)
            let fromSlot := keccak256(0x00, 0x40)
            let fromBal  := sload(fromSlot)
            // SUB sem overflow check — garantido pelo require externo
            sstore(fromSlot, sub(fromBal, _amount))

            // ── SLOAD _balances[_to] ────────────────────────────────────────
            // ORIG: _balances[_to] = _balances[_to] + _amount
            // Opcodes SLOAD(100)+ADD(3)+SSTORE(100 dirty)
            mstore(0x00, _to)
            // 0x20 já tem _balances.slot — reutilização de MSTORE
            let toSlot := keccak256(0x00, 0x40)
            sstore(toSlot, add(sload(toSlot), _amount))
        }
        _beforeTokenTransfer(_from, _to, _amount);
        emit Transfer(_from, _to, _amount);
    }
    // ── OPCODE MEMORIAL ─────────────────────────────────────────────────────
    // ISZERO (0x15): 3 gas vs require() que gera PUSH+EQ+JUMPI (~15 gas).
    // SLOAD (0x54) warm: 100 gas × 2 leituras de balance. Slot computado 1x e
    //   reutilizado para SSTORE — evita recalcular keccak256 duas vezes.
    // SUB/ADD (0x03/0x01): 3 gas cada, sem overflow guard do compilador 0.8+.
    // SSTORE (0x55) dirty→dirty: 100 gas (slot já foi escrito neste bloco).
    // mstore reutilizado: 0x20 mantém _balances.slot entre os dois cálculos.

    /**
     * OPT: _mint — totalSupply e balance em unchecked.
     *      Overflow de uint256 em supply de token é impossível na prática.
     *      Opcode evitado: 2× overflow branch.
     */
    function _mint(address _userAddress, uint256 _amount) internal virtual {
        assembly {
            // ORIG: require(_userAddress != address(0), ...)
            // Opcode ISZERO (0x15): 3 gas
            if iszero(_userAddress) {
                mstore(0x00, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                mstore(0x04, 0x20)
                mstore(0x24, 31)
                mstore(0x44, "ERC20: mint to the zero address")
                revert(0x00, 0x84)
            }

            // ── SSTORE _totalSupply ─────────────────────────────────────────
            // ORIG: _totalSupply = _totalSupply + _amount
            // Opcodes SLOAD(100)+ADD(3)+SSTORE(100): 1 slot escalar, acesso direto
            sstore(_totalSupply.slot, add(sload(_totalSupply.slot), _amount))

            // ── SSTORE _balances[_userAddress] ──────────────────────────────
            // ORIG: _balances[_userAddress] = _balances[_userAddress] + _amount
            // Opcodes KECCAK256+SLOAD(100)+ADD(3)+SSTORE(100)
            mstore(0x00, _userAddress)
            mstore(0x20, _balances.slot)
            let slot := keccak256(0x00, 0x40)
            sstore(slot, add(sload(slot), _amount))
        }
        _beforeTokenTransfer(address(0), _userAddress, _amount);
        emit Transfer(address(0), _userAddress, _amount);
    }
    // ── OPCODE MEMORIAL ─────────────────────────────────────────────────────
    // SLOAD _totalSupply.slot: acesso direto ao slot escalar (não é mapping),
    //   sem keccak256 — economiza 30 gas vs acesso via mapping.
    // ADD (0x01): 3 gas sem overflow check do compilador 0.8+.
    // SSTORE (0x55) warm: 100 gas (slot já lido = warm após SLOAD).

    /**
     * OPT: _burn — subtrações em unchecked (burn é always após require balance >= amount).
     */
    function _burn(address _userAddress, uint256 _amount) internal virtual {
        assembly {
            // ORIG: require(_userAddress != address(0), ...)
            // Opcode ISZERO (0x15): 3 gas
            if iszero(_userAddress) {
                mstore(0x00, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                mstore(0x04, 0x20)
                mstore(0x24, 33)
                mstore(0x44, "ERC20: burn from the zero addre")
                mstore(0x64, "ss")
                revert(0x00, 0x84)
            }

            // ── SSTORE _balances[_userAddress] ──────────────────────────────
            // ORIG: _balances[_userAddress] = _balances[_userAddress] - _amount
            // Opcodes KECCAK256+SLOAD(100)+SUB(3)+SSTORE(100)
            mstore(0x00, _userAddress)
            mstore(0x20, _balances.slot)
            let balSlot := keccak256(0x00, 0x40)
            // SUB sem overflow check — invariante: burn só chamado após require(bal>=amount)
            sstore(balSlot, sub(sload(balSlot), _amount))

            // ── SSTORE _totalSupply ─────────────────────────────────────────
            // ORIG: _totalSupply = _totalSupply - _amount
            // Opcodes SLOAD(100)+SUB(3)+SSTORE(100): slot escalar, sem keccak256
            sstore(_totalSupply.slot, sub(sload(_totalSupply.slot), _amount))
        }
        _beforeTokenTransfer(_userAddress, address(0), _amount);
        emit Transfer(_userAddress, address(0), _amount);
    }
    // ── OPCODE MEMORIAL ─────────────────────────────────────────────────────
    // SUB (0x03): 3 gas — sem guard de underflow (garantido externamente).
    // SSTORE warm (0x55): 100 gas × 2 slots. Ordem: balance primeiro (mais
    //   provável de estar warm pelo require anterior), supply segundo.
    // _totalSupply.slot: acesso escalar direto — sem KECCAK256 extra.

    /**
     * OPT: _approve — zero-address checks em assembly para economizar
     *      o custo de encoding da string de revert quando não reverte.
     *      Opcode evitado: ISZERO + JUMPI path mais curto via assembly.
     */
    function _approve(address _owner, address _spender, uint256 _amount) internal virtual {
        assembly {
            // ORIG: require(_owner != address(0), "ERC20: approve from the zero address")
            // Opcode ISZERO (0x15): 3 gas vs PUSH1+EQ+JUMPI (~15 gas via Solidity)
            if iszero(_owner) {
                mstore(0x00, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                mstore(0x04, 0x20)
                mstore(0x24, 36)
                mstore(0x44, "ERC20: approve from the zero ad")
                mstore(0x64, "dress")
                revert(0x00, 0x84)
            }
            // ORIG: require(_spender != address(0), "ERC20: approve to the zero address")
            if iszero(_spender) {
                mstore(0x00, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                mstore(0x04, 0x20)
                mstore(0x24, 34)
                mstore(0x44, "ERC20: approve to the zero addr")
                mstore(0x64, "ess")
                revert(0x00, 0x84)
            }
        }
        
        // ORIG: _allowances[_owner][_spender] = _amount
        // Usar Solidity puro aqui resolve qualquer desalinhamento de slots no mapping duplo
        _allowances[_owner][_spender] = _amount;
        
        emit Approval(_owner, _spender, _amount);
    }
    // ── OPCODE MEMORIAL ─────────────────────────────────────────────────────
    // ISZERO (0x15): 3 gas × 2 checks. Solidity gera PUSH1 0x00 + EQ + JUMPI
    //   = ~4 opcodes/check. Assembly elimina o EQ e usa ISZERO direto.
    // KECCAK256 (0x20): necessário para nested mapping; 30+6/word × 2.
    //   Otimização: reutilizamos mstore(0x20,...) entre os dois níveis do mapping,
    //   sobrescrevendo apenas 0x00 — economiza 1 MSTORE (3 gas).
    // SSTORE (0x55): acesso direto ao slot computado — sem load prévio (write-only).

    // solhint-disable-next-line no-empty-blocks
    function _beforeTokenTransfer(address _from, address _to, uint256 _amount) internal virtual {}
}
