// SPDX-License-Identifier: GPL-3.0
//
//                                             :+#####%%%%%%%%%%%%%%+
//                                         .-*@@@%+.:+%@@@@@%%#***%@@%=
//                                     :=*%@@@#=.      :#@@%       *@@@%=
//                       .-+*%@%*-.:+%@@@@@@+.     -*+:  .=#.       :%@@@%-
//                   :=*@@@@%%@@@@@@@@@%@@@-   .=#@@@%@%=             =@@@@#.
//             -=+#%@@%#*=:.  :%@@@@%.   -*@@#*@@@@@@@#=:-              *@@@@+
//            =@@%=:.     :=:   *@@@@@%#-   =%*%@@@@#+-.        =+       :%@@@%-
//           -@@%.     .+@@@     =+=-.         @@#-           +@@@%-       =@@@@%:
//          :@@@.    .+@@#%:                   :    .=*=-::.-%@@@+*@@=       +@@@@#.
//          %@@:    +@%%*                         =%@@@@@@@@@@@#.  .*@%-       +@@@@*.
//         #@@=                                .+@@@@%:=*@@@@@-      :%@%:      .*@@@@+
//        *@@*                                +@@@#-@@%-:%@@*          +@@#.      :%@@@@-
//       -@@%           .:-=++*##%%%@@@@@@@@@@@@*. :@+.@@@%:            .#@@+       =@@@@#:
//      .@@@*-+*#%%%@@@@@@@@@@@@@@@@%%#**@@%@@@.   *@=*@@#                :#@%=      .#@@@@#-
//      -%@@@@@@@@@@@@@@@*+==-:-@@@=    *@# .#@*-=*@@@@%=                 -%@@@*       =@@@@@%-
//         -+%@@@#.   %@%%=   -@@:+@: -@@*    *@@*-::                   -%@@%=.         .*@@@@@#
//            *@@@*  +@* *@@##@@-  #@*@@+    -@@=          .         :+@@@#:           .-+@@@%+-
//             +@@@%*@@:..=@@@@*   .@@@*   .#@#.       .=+-       .=%@@@*.         :+#@@@@*=:
//              =@@@@%@@@@@@@@@@@@@@@@@@@@@@%-      :+#*.       :*@@@%=.       .=#@@@@%+:
//               .%@@=                 .....    .=#@@+.       .#@@@*:       -*%@@@@%+.
//                 +@@#+===---:::...         .=%@@*-         +@@@+.      -*@@@@@%+.
//                  -@@@@@@@@@@@@@@@@@@@@@@%@@@@=          -@@@+      -#@@@@@#=.
//                    ..:::---===+++***###%%%@@@#-       .#@@+     -*@@@@@#=.
//                                           @@@@@@+.   +@@*.   .+@@@@@%=.
//                                          -@@@@@=   =@@%:   -#@@@@%+.
//                                          +@@@@@. =@@@=  .+@@@@@*:
//                                          #@@@@#:%@@#. :*@@@@#-
//                                          @@@@@%@@@= :#@@@@+.
//                                         :@@@@@@@#.:#@@@%-
//                                         +@@@@@@-.*@@@*:
//                                         #@@@@#.=@@@+.
//                                         @@@@+-%@%=
//                                        :@@@#%@%=
//                                        +@@@@%-
//                                        :#%%=
//
/**
 *     NOTICE
 *
 *     The T-REX software is licensed under a proprietary license or the GPL v.3.
 *     If you choose to receive it under the GPL v.3 license, the following applies:
 *     T-REX is a suite of smart contracts implementing the ERC-3643 standard and
 *     developed by Tokeny to manage and transfer financial assets on EVM blockchains
 *
 *     Copyright (C) 2023, Tokeny sàrl.
 *
 *     This program is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     This program is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../../token/IToken.sol";
import "./IModularCompliance.sol";
import "./MCStorage.sol";
import "./modules/IModule.sol";


contract ModularCompliance is IModularCompliance, OwnableUpgradeable, MCStorage {

    /// modifiers

    /**
     * @dev Throws if called by any address that is not a token bound to the compliance.
     */
    modifier onlyToken() {
        require(msg.sender == _tokenBound, "error : this address is not a token bound to the compliance contract");
        _;
    }

    function init() external initializer {
        __Ownable_init();
    }

    /**
     *  @dev See {IModularCompliance-bindToken}.
     */
    function bindToken(address _token) external override {
        require(owner() == msg.sender || (_tokenBound == address(0) && msg.sender == _token),
        "only owner or token can call");
        require(_token != address(0), "invalid argument - zero address");
        _tokenBound = _token;
        emit TokenBound(_token);
    }

    /**
    *  @dev See {IModularCompliance-unbindToken}.
    */
    function unbindToken(address _token) external override {
        require(owner() == msg.sender || msg.sender == _token , "only owner or token can call");
        require(_token == _tokenBound, "This token is not bound");
        require(_token != address(0), "invalid argument - zero address");
        delete _tokenBound;
        emit TokenUnbound(_token);
    }

    /**
     *  @dev See {IModularCompliance-addModule}.
     */
    function addModule(address _module) external override onlyOwner {
        require(_module != address(0), "invalid argument - zero address");
        require(!_moduleBound[_module], "module already bound");
        require(_modules.length <= 24, "cannot add more than 25 modules");
        IModule module = IModule(_module);
        if (!module.isPlugAndPlay()) {
            require(module.canComplianceBind(address(this)), "compliance is not suitable for binding to the module");
        }

        module.bindCompliance(address(this));
        _modules.push(_module);
        _moduleBound[_module] = true;
        emit ModuleAdded(_module);
    }

    /**
     *  @dev See {IModularCompliance-removeModule}.
     */
    function removeModule(address _module) external override onlyOwner {
        // ORIG: require(_module != address(0), ...)
        // Opcode ISZERO (0x15): 3 gas vs PUSH+EQ+JUMPI
        assembly {
            if iszero(_module) {
                mstore(0x00, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                mstore(0x04, 0x20)
                mstore(0x24, 31)
                mstore(0x44, "invalid argument - zero address")
                revert(0x00, 0x84)
            }
        }
        require(_moduleBound[_module], "module not bound");
        // ORIG: for (uint256 i = 0; i < length; i++)
        // OPT : unchecked ++i + unchecked SUB
        uint256 length = _modules.length;
        for (uint256 i = 0; i < length; ) {
            if (_modules[i] == _module) {
                IModule(_module).unbindCompliance(address(this));
                // ORIG: _modules[i] = _modules[length - 1]
                // Opcode SUB (0x03): sem guard — loop só roda se length > 0
                unchecked { _modules[i] = _modules[length - 1]; }
                _modules.pop();
                _moduleBound[_module] = false;
                emit ModuleRemoved(_module);
                break;
            }
            unchecked { ++i; }
        }
    }
    // ── OPCODE MEMORIAL ─────────────────────────────────────────────────────
    // ISZERO (0x15): 3 gas zero-check sem EQ extra.
    // SUB unchecked (0x03): index final sem guard de underflow.
    // unchecked ++i: ~15 gas por iteração economizados.

    /**
    *  @dev See {IModularCompliance-transferred}.
    */
    function transferred(address _from, address _to, uint256 _value) external onlyToken override {
        // ORIG: require(_from != address(0) && _to != address(0), ...)
        // Opcode ISZERO (0x15) + OR (0x17): 2 checks em assembly mais baratos.
        assembly {
            if or(iszero(_from), iszero(_to)) {
                mstore(0x00, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                mstore(0x04, 0x20)
                mstore(0x24, 31)
                mstore(0x44, "invalid argument - zero address")
                revert(0x00, 0x84)
            }
        }
        require(_value > 0, "invalid argument - no value transfer");
        // ORIG: for (uint256 i = 0; i < length; i++)
        // OPT : unchecked ++i + length cacheado
        // Opcode SLOAD warm (0x54): _modules.length lido 1x.
        uint256 length = _modules.length;
        for (uint256 i = 0; i < length; ) {
            IModule(_modules[i]).moduleTransferAction(_from, _to, _value);
            unchecked { ++i; }
        }
    }
    // ── OPCODE MEMORIAL ─────────────────────────────────────────────────────
    // OR (0x17): 3 gas — combina 2 ISZERO em 1 branch. Solidity gerava 2 JUMPI
    //   separados = ~20 gas. Assembly: ~9 gas (ISZERO+ISZERO+OR+JUMPI).
    // unchecked ++i: chamado em todo transfer — economia de ~15 gas × N_modules.

    /**
     *  @dev See {IModularCompliance-created}.
     */
    function created(address _to, uint256 _value) external onlyToken override {
        // ORIG: require(_to != address(0), ...) — ISZERO direto
        assembly {
            if iszero(_to) {
                mstore(0x00, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                mstore(0x04, 0x20)
                mstore(0x24, 31)
                mstore(0x44, "invalid argument - zero address")
                revert(0x00, 0x84)
            }
        }
        require(_value > 0, "invalid argument - no value mint");
        // ORIG: for (uint256 i = 0; i < length; i++)
        // OPT : unchecked ++i
        uint256 length = _modules.length;
        for (uint256 i = 0; i < length; ) {
            IModule(_modules[i]).moduleMintAction(_to, _value);
            unchecked { ++i; }
        }
    }

    /**
     *  @dev See {IModularCompliance-destroyed}.
     */
    function destroyed(address _from, uint256 _value) external onlyToken override {
        // ORIG: require(_from != address(0), ...) — ISZERO direto
        assembly {
            if iszero(_from) {
                mstore(0x00, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                mstore(0x04, 0x20)
                mstore(0x24, 31)
                mstore(0x44, "invalid argument - zero address")
                revert(0x00, 0x84)
            }
        }
        require(_value > 0, "invalid argument - no value burn");
        // ORIG: for (uint256 i = 0; i < length; i++)
        // OPT : unchecked ++i — chamado em todo burn
        uint256 length = _modules.length;
        for (uint256 i = 0; i < length; ) {
            IModule(_modules[i]).moduleBurnAction(_from, _value);
            unchecked { ++i; }
        }
    }
    // ── OPCODE MEMORIAL (created + destroyed) ────────────────────────────
    // ISZERO (0x15): 3 gas por zero-check vs PUSH1+EQ+JUMPI (~15 gas).
    // unchecked ++i: eliminados ~15 gas/iter em 2 funções chamadas em mint/burn.

    /**
     *  @dev see {IModularCompliance-callModuleFunction}.
     */
    function callModuleFunction(bytes calldata callData, address _module) external override onlyOwner {
        require(_moduleBound[_module], "call only on bound module");
        // NOTE: Use assembly to call the interaction instead of a low level
        // call for two reasons:
        // - We don't want to copy the return data, since we discard it for
        // interactions.
        // - Solidity will under certain conditions generate code to copy input
        // calldata twice to memory (the second being a "memcopy loop").
        // solhint-disable-next-line no-inline-assembly
        assembly {
            let freeMemoryPointer := mload(0x40)
            calldatacopy(freeMemoryPointer, callData.offset, callData.length)
            if iszero(
            call(
            gas(),
            _module,
            0,
            freeMemoryPointer,
            callData.length,
            0,
            0
            ))
            {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }

        emit ModuleInteraction(_module, _selector(callData));

    }

    /**
     *  @dev See {IModularCompliance-isModuleBound}.
     */
    function isModuleBound(address _module) external view override returns (bool) {
        return _moduleBound[_module];
    }

    /**
     *  @dev See {IModularCompliance-getModules}.
     */
    function getModules() external view override returns (address[] memory) {
        return _modules;
    }

    /**
     *  @dev See {IModularCompliance-getTokenBound}.
     */
    function getTokenBound() external view override returns (address) {
        return _tokenBound;
    }

    /**
     *  @dev See {IModularCompliance-canTransfer}.
     */
    function canTransfer(address _from, address _to, uint256 _value) external view override returns (bool) {
        // ORIG: for (uint256 i = 0; i < length; i++)
        // OPT : unchecked ++i — canTransfer é chamado em TODO transfer do sistema.
        // Opcode SLOAD warm (0x54): length lido 1x.
        // unchecked ++i: ~15 gas × N_modules por transfer.
        uint256 length = _modules.length;
        for (uint256 i = 0; i < length; ) {
            if (!IModule(_modules[i]).moduleCheck(_from, _to, _value, address(this))) {
                return false;
            }
            unchecked { ++i; }
        }
        return true;
    }
    // ── OPCODE MEMORIAL ─────────────────────────────────────────────────────
    // canTransfer é chamado em TODO transfer: impacto direto de ~15 gas × N_modules
    // por transação. Com 25 módulos (max): 375 gas economizados por transfer.

    /// @dev Extracts the Solidity ABI selector for the specified interaction.
    /// @param callData Interaction data.
    /// @return result The 4 byte function selector of the call encoded in
    /// this interaction.
    function _selector(bytes calldata callData) internal pure returns (bytes4 result) {
        if (callData.length >= 4) {
            // NOTE: Read the first word of the interaction's calldata. The
            // value does not need to be shifted since `bytesN` values are left
            // aligned, and the value does not need to be masked since masking
            // occurs when the value is accessed and not stored:
            // <https://docs.soliditylang.org/en/v0.7.6/abi-spec.html#encoding-of-indexed-event-parameters>
            // <https://docs.soliditylang.org/en/v0.7.6/assembly.html#access-to-external-variables-functions-and-libraries>
            // solhint-disable-next-line no-inline-assembly
            assembly {
                result := calldataload(callData.offset)
            }
        }
    }
}

