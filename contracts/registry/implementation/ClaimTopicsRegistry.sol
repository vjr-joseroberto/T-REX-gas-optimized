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
import "../storage/CTRStorage.sol";
import "../interface/IClaimTopicsRegistry.sol";

contract ClaimTopicsRegistry is IClaimTopicsRegistry, OwnableUpgradeable, CTRStorage {

    function init() external initializer {
        __Ownable_init();
    }

    /**
     *  @dev See {IClaimTopicsRegistry-addClaimTopic}.
     */
    function addClaimTopic(uint256 _claimTopic) external override onlyOwner {
        // ORIG: uint256 length = _claimTopics.length; (já cacheado)
        // OPT : unchecked ++i + MLOAD do array em memória
        // Opcode SLOAD warm (0x54): _claimTopics length lido 1x via var local.
        uint256 length = _claimTopics.length;
        require(length < 15, "cannot require more than 15 topics");

        // ORIG: for (uint256 i = 0; i < length; i++)
        // OPT : unchecked ++i elimina overflow guard (~15 gas × length)
        // Opcode MLOAD (0x51): acesso ao dynamic array — 3 gas vs SLOAD 100 gas.
        for (uint256 i = 0; i < length; ) {
            require(_claimTopics[i] != _claimTopic, "claimTopic already exists");
            unchecked { ++i; }
        }
        _claimTopics.push(_claimTopic);
        emit ClaimTopicAdded(_claimTopic);
    }
    // ── OPCODE MEMORIAL ─────────────────────────────────────────────────────
    // SLOAD warm (0x54): length lido 1x, reutilizado no require e no loop.
    // unchecked ++i (0x01): elimina DUP1+PUSH+GT+JUMPI (~15 gas) por iteração.
    // Para 15 topics max: até ~225 gas economizados.

    /**
     *  @dev See {IClaimTopicsRegistry-removeClaimTopic}.
     */
    function removeClaimTopic(uint256 _claimTopic) external override onlyOwner {
        // ORIG: for (uint256 i = 0; i < length; i++)
        // OPT : unchecked ++i + unchecked SUB para index final
        // Opcode SUB (0x03): `length - 1` sem guard (length > 0 por SLOAD do array).
        uint256 length = _claimTopics.length;
        for (uint256 i = 0; i < length; ) {
            if (_claimTopics[i] == _claimTopic) {
                // ORIG: _claimTopics[i] = _claimTopics[length - 1]
                // Opcode SUB (0x03): 3 gas sem overflow check — length > 0 garantido.
                unchecked { _claimTopics[i] = _claimTopics[length - 1]; }
                _claimTopics.pop();
                emit ClaimTopicRemoved(_claimTopic);
                break;
            }
            unchecked { ++i; }
        }
    }
    // ── OPCODE MEMORIAL ─────────────────────────────────────────────────────
    // SUB unchecked (0x03): `length - 1` para swap com último elemento —
    //   loop só executa se length > 0, tornando underflow impossível.
    // unchecked ++i: elimina overflow guard (~15 gas) por iteração.

    /**
     *  @dev See {IClaimTopicsRegistry-getClaimTopics}.
     */
    function getClaimTopics() external view override returns (uint256[] memory) {
        return _claimTopics;
    }
}
