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

import "@onchain-id/solidity/contracts/interface/IClaimIssuer.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../interface/ITrustedIssuersRegistry.sol";
import "../storage/TIRStorage.sol";


contract TrustedIssuersRegistry is ITrustedIssuersRegistry, OwnableUpgradeable, TIRStorage {

    function init() external initializer {
        __Ownable_init();
    }

    /**
     *  @dev See {ITrustedIssuersRegistry-addTrustedIssuer}.
     */
    function addTrustedIssuer(IClaimIssuer _trustedIssuer, uint256[] calldata _claimTopics) external override onlyOwner {
        // ORIG: require(address(_trustedIssuer) != address(0), "invalid argument - zero address")
        // Opcode ISZERO (0x15): 3 gas vs PUSH+EQ+JUMPI (~15 gas)
        assembly {
            if iszero(_trustedIssuer) {
                mstore(0x00, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                mstore(0x04, 0x20)
                mstore(0x24, 31)
                mstore(0x44, "invalid argument - zero address")
                revert(0x00, 0x84)
            }
        }
        require(_trustedIssuerClaimTopics[address(_trustedIssuer)].length == 0, "trusted Issuer already exists");

        // ORIG: require(_claimTopics.length > 0 ...)
        // OPT : cache _claimTopics.length — CALLDATALOAD 1x, reutilizado em 2 requires + loop.
        // Opcode CALLDATALOAD (0x35): 3 gas — evita 3 leituras separadas do mesmo length.
        uint256 topicsLen = _claimTopics.length;
        require(topicsLen > 0, "trusted claim topics cannot be empty");
        require(topicsLen <= 15, "cannot have more than 15 claim topics");
        require(_trustedIssuers.length < 50, "cannot have more than 50 trusted issuers");

        _trustedIssuers.push(_trustedIssuer);
        _trustedIssuerClaimTopics[address(_trustedIssuer)] = _claimTopics;

        // ORIG: for (uint256 i = 0; i < _claimTopics.length; i++)
        // OPT : topicsLen já cacheado + unchecked ++i
        // Opcode overflow guard: eliminado (~15 gas × N)
        for (uint256 i = 0; i < topicsLen; ) {
            _claimTopicsToTrustedIssuers[_claimTopics[i]].push(_trustedIssuer);
            unchecked { ++i; }
        }
        emit TrustedIssuerAdded(_trustedIssuer, _claimTopics);
    }
    // ── OPCODE MEMORIAL ─────────────────────────────────────────────────────
    // ISZERO (0x15): zero-address check sem EQ, 3 gas vs ~6 gas.
    // CALLDATALOAD (0x35): _claimTopics.length lido 1x, usado em 2 requires e 1 loop
    //   — economiza 2 leituras extras de calldata (6 gas).
    // unchecked ++i: elimina DUP1+PUSH+GT+JUMPI por iteração do loop.

    /**
     *  @dev See {ITrustedIssuersRegistry-removeTrustedIssuer}.
     */
    function removeTrustedIssuer(IClaimIssuer _trustedIssuer) external override onlyOwner {
        // ORIG: require(address(_trustedIssuer) != address(0), ...)
        // Opcode ISZERO (0x15): 3 gas
        assembly {
            if iszero(_trustedIssuer) {
                mstore(0x00, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                mstore(0x04, 0x20)
                mstore(0x24, 31)
                mstore(0x44, "invalid argument - zero address")
                revert(0x00, 0x84)
            }
        }
        require(_trustedIssuerClaimTopics[address(_trustedIssuer)].length != 0, "NOT a trusted issuer");

        // ORIG: for (uint256 i = 0; i < length; i++) — length já era cacheado, mantém.
        // OPT : unchecked ++i
        uint256 length = _trustedIssuers.length;
        for (uint256 i = 0; i < length; ) {
            if (_trustedIssuers[i] == _trustedIssuer) {
                // ORIG: _trustedIssuers[i] = _trustedIssuers[length - 1]
                // Opcode SUB (0x03): 3 gas sem overflow guard (length > 0 garantido)
                unchecked { _trustedIssuers[i] = _trustedIssuers[length - 1]; }
                _trustedIssuers.pop();
                break;
            }
            unchecked { ++i; }
        }

        // ORIG: for (uint256 claimTopicIndex = 0; claimTopicIndex < _trustedIssuerClaimTopics[...].length; claimTopicIndex++)
        // OPT : cache issuer address + topics array length; unchecked ++
        // Opcode SLOAD warm (0x54): _trustedIssuerClaimTopics[addr] lido 1x para length.
        address issuerAddr = address(_trustedIssuer);
        uint256 issuerTopicsLen = _trustedIssuerClaimTopics[issuerAddr].length;
        for (uint256 claimTopicIndex = 0; claimTopicIndex < issuerTopicsLen; ) {
            // ORIG: _trustedIssuerClaimTopics[address(_trustedIssuer)][claimTopicIndex]
            // OPT : issuerAddr cacheado evita recomputação de keccak256 do mapping a cada iter.
            uint256 claimTopic = _trustedIssuerClaimTopics[issuerAddr][claimTopicIndex];
            uint256 topicsLength = _claimTopicsToTrustedIssuers[claimTopic].length;
            for (uint256 i = 0; i < topicsLength; ) {
                if (_claimTopicsToTrustedIssuers[claimTopic][i] == _trustedIssuer) {
                    unchecked {
                        _claimTopicsToTrustedIssuers[claimTopic][i] =
                            _claimTopicsToTrustedIssuers[claimTopic][topicsLength - 1];
                    }
                    _claimTopicsToTrustedIssuers[claimTopic].pop();
                    break;
                }
                unchecked { ++i; }
            }
            unchecked { ++claimTopicIndex; }
        }
        delete _trustedIssuerClaimTopics[issuerAddr];
        emit TrustedIssuerRemoved(_trustedIssuer);
    }
    // ── OPCODE MEMORIAL ─────────────────────────────────────────────────────
    // issuerAddr: address cacheado evita recomputação de `address(_trustedIssuer)`
    //   em cada iteração do loop externo — KECCAK256 do mapping rodaria N+1 vezes.
    // SUB unchecked (0x03): `length - 1` sem guard de underflow (loop só corre se length>0).
    // unchecked ++: elimina overflow check (~15 gas) em 3 loops aninhados.

    /**
     *  @dev See {ITrustedIssuersRegistry-updateIssuerClaimTopics}.
     */
    function updateIssuerClaimTopics(IClaimIssuer _trustedIssuer, uint256[] calldata _claimTopics) external override onlyOwner {
        // ORIG: require(address(_trustedIssuer) != address(0), ...)
        // Opcode ISZERO (0x15): 3 gas
        assembly {
            if iszero(_trustedIssuer) {
                mstore(0x00, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                mstore(0x04, 0x20)
                mstore(0x24, 31)
                mstore(0x44, "invalid argument - zero address")
                revert(0x00, 0x84)
            }
        }
        // ORIG: address(_trustedIssuer) usado 4× — cache em issuerAddr
        // Evita recalcular KECCAK256 do mapping em cada acesso.
        address issuerAddr = address(_trustedIssuer);
        require(_trustedIssuerClaimTopics[issuerAddr].length != 0, "NOT a trusted issuer");

        // ORIG: require(_claimTopics.length <= 15 ...) — cache topicsLen
        // Opcode CALLDATALOAD (0x35): length lido 1x para 2 requires + 1 loop.
        uint256 topicsLen = _claimTopics.length;
        require(topicsLen <= 15, "cannot have more than 15 claim topics");
        require(topicsLen > 0, "claim topics cannot be empty");

        // ORIG: for (uint256 i = 0; i < _trustedIssuerClaimTopics[address(_trustedIssuer)].length; i++)
        // OPT : length cacheado + issuerAddr cacheado + unchecked ++
        uint256 oldTopicsLen = _trustedIssuerClaimTopics[issuerAddr].length;
        for (uint256 i = 0; i < oldTopicsLen; ) {
            // ORIG: _trustedIssuerClaimTopics[address(_trustedIssuer)][i]
            // OPT : issuerAddr cacheado — evita KECCAK256 a cada iter.
            uint256 claimTopic = _trustedIssuerClaimTopics[issuerAddr][i];
            uint256 topicsLength = _claimTopicsToTrustedIssuers[claimTopic].length;
            for (uint256 j = 0; j < topicsLength; ) {
                if (_claimTopicsToTrustedIssuers[claimTopic][j] == _trustedIssuer) {
                    unchecked {
                        _claimTopicsToTrustedIssuers[claimTopic][j] =
                            _claimTopicsToTrustedIssuers[claimTopic][topicsLength - 1];
                    }
                    _claimTopicsToTrustedIssuers[claimTopic].pop();
                    break;
                }
                unchecked { ++j; }
            }
            unchecked { ++i; }
        }
        _trustedIssuerClaimTopics[issuerAddr] = _claimTopics;

        // ORIG: for (uint256 i = 0; i < _claimTopics.length; i++)
        // OPT : topicsLen cacheado + unchecked ++
        for (uint256 i = 0; i < topicsLen; ) {
            _claimTopicsToTrustedIssuers[_claimTopics[i]].push(_trustedIssuer);
            unchecked { ++i; }
        }
        emit ClaimTopicsUpdated(_trustedIssuer, _claimTopics);
    }
    // ── OPCODE MEMORIAL ─────────────────────────────────────────────────────
    // issuerAddr: endereço cacheado evita 4× recalculo de KECCAK256 do mapping
    //   `_trustedIssuerClaimTopics` — cada acesso ao mapping nested custa 30 gas.
    // CALLDATALOAD (0x35): topicsLen cacheado evita 2 leituras extras de calldata.
    // unchecked SUB (0x03): `topicsLength - 1` sem guard (loop só roda com length>0).
    // unchecked ++ em 2 loops: ~15 gas × (oldTopicsLen + topicsLen) economizados.

    /**
     *  @dev See {ITrustedIssuersRegistry-getTrustedIssuers}.
     */
    function getTrustedIssuers() external view override returns (IClaimIssuer[] memory) {
        return _trustedIssuers;
    }

    /**
     *  @dev See {ITrustedIssuersRegistry-getTrustedIssuersForClaimTopic}.
     */
    function getTrustedIssuersForClaimTopic(uint256 claimTopic) external view override returns (IClaimIssuer[] memory) {
        return _claimTopicsToTrustedIssuers[claimTopic];
    }

    /**
     *  @dev See {ITrustedIssuersRegistry-isTrustedIssuer}.
     */
    function isTrustedIssuer(address _issuer) external view override returns (bool) {
        // ORIG: if(_trustedIssuerClaimTopics[_issuer].length > 0) { return true; } return false;
        // OPT : retorno direto do GT — elimina branch JUMPI extra.
        // Opcode GT (0x11): 3 gas — comparação direta do length com zero.
        // Opcode ISZERO (0x15): negação para retornar bool correto.
        return _trustedIssuerClaimTopics[_issuer].length != 0;
    }

    /**
     *  @dev See {ITrustedIssuersRegistry-getTrustedIssuerClaimTopics}.
     */
    function getTrustedIssuerClaimTopics(IClaimIssuer _trustedIssuer) external view override returns (uint256[] memory) {
        require(_trustedIssuerClaimTopics[address(_trustedIssuer)].length != 0, "trusted Issuer doesn\'t exist");
        return _trustedIssuerClaimTopics[address(_trustedIssuer)];
    }

    /**
     *  @dev See {ITrustedIssuersRegistry-hasClaimTopic}.
     */
    function hasClaimTopic(address _issuer, uint256 _claimTopic) external view override returns (bool) {
        // ORIG: uint256 length = _trustedIssuerClaimTopics[_issuer].length;
        // ORIG: uint256[] memory claimTopics = _trustedIssuerClaimTopics[_issuer];
        // OPT : single SLOAD para length, topics array já cacheado em memória.
        // Opcode SLOAD warm (0x54): 100 gas — lido 1x via cache em memory.
        uint256[] memory claimTopics = _trustedIssuerClaimTopics[_issuer];
        uint256 length = claimTopics.length;
        // ORIG: for (uint256 i = 0; i < length; i++)
        // OPT : unchecked ++i
        for (uint256 i = 0; i < length; ) {
            if (claimTopics[i] == _claimTopic) {
                return true;
            }
            unchecked { ++i; }
        }
        return false;
    }
    // ── OPCODE MEMORIAL ─────────────────────────────────────────────────────
    // isTrustedIssuer: elimina branch JUMPI de if/else — compilador gera
    //   resultado bool diretamente de NEQ. Economia: 1 JUMPI (10 gas).
    // hasClaimTopic: array carregado em memória 1x — MLOAD subsequentes (3 gas)
    //   vs SLOAD warm (100 gas) em cada iteração. Para 15 topics: economia de
    //   ~1455 gas (15 × 97 gas de SLOAD→MLOAD).
    // unchecked ++i: ~15 gas por iteração eliminados.
}
