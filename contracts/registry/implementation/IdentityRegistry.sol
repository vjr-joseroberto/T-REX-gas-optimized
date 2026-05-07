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
import "@onchain-id/solidity/contracts/interface/IIdentity.sol";

import "../interface/IClaimTopicsRegistry.sol";
import "../interface/ITrustedIssuersRegistry.sol";
import "../interface/IIdentityRegistry.sol";
import "../../roles/AgentRoleUpgradeable.sol";
import "../interface/IIdentityRegistryStorage.sol";
import "../storage/IRStorage.sol";


contract IdentityRegistry is IIdentityRegistry, AgentRoleUpgradeable, IRStorage {

    /**
     *  @dev the constructor initiates the Identity Registry smart contract
     *  @param _trustedIssuersRegistry the trusted issuers registry linked to the Identity Registry
     *  @param _claimTopicsRegistry the claim topics registry linked to the Identity Registry
     *  @param _identityStorage the identity registry storage linked to the Identity Registry
     *  emits a `ClaimTopicsRegistrySet` event
     *  emits a `TrustedIssuersRegistrySet` event
     *  emits an `IdentityStorageSet` event
     */
    function init(
        address _trustedIssuersRegistry,
        address _claimTopicsRegistry,
        address _identityStorage
    ) external initializer {
        require(
            _trustedIssuersRegistry != address(0)
            && _claimTopicsRegistry != address(0)
            && _identityStorage != address(0)
        , "invalid argument - zero address");
        _tokenTopicsRegistry = IClaimTopicsRegistry(_claimTopicsRegistry);
        _tokenIssuersRegistry = ITrustedIssuersRegistry(_trustedIssuersRegistry);
        _tokenIdentityStorage = IIdentityRegistryStorage(_identityStorage);
        emit ClaimTopicsRegistrySet(_claimTopicsRegistry);
        emit TrustedIssuersRegistrySet(_trustedIssuersRegistry);
        emit IdentityStorageSet(_identityStorage);
        __Ownable_init();
    }

    /**
     *  @dev See {IIdentityRegistry-batchRegisterIdentity}.
     */
    function batchRegisterIdentity(
        address[] calldata _userAddresses,
        IIdentity[] calldata _identities,
        uint16[] calldata _countries
    ) external override {
        // ORIG: for (uint256 i = 0; i < _userAddresses.length; i++)
        // OPT : cache length + unchecked ++i
        // Opcode CALLDATALOAD (0x35): length lido 1x em vez de a cada iteração.
        // Opcode overflow guard eliminado: ++i em unchecked poupa DUP+GT+JUMPI (~15 gas×N).
        uint256 len = _userAddresses.length;
        for (uint256 i = 0; i < len; ) {
            registerIdentity(_userAddresses[i], _identities[i], _countries[i]);
            unchecked { ++i; }
        }
    }
    // ── OPCODE MEMORIAL ─────────────────────────────────────────────────────
    // CALLDATALOAD (0x35): 3 gas — length cacheado em var local evita re-leitura
    //   do calldata a cada iteração do loop.
    // ADD/overflow guard: unchecked elimina ~15 gas por iteração (DUP1+PUSH+GT+JUMPI).
    // Para 100 identidades: economia de ~1500 gas.

    /**
     *  @dev See {IIdentityRegistry-updateIdentity}.
     */
    function updateIdentity(address _userAddress, IIdentity _identity) external override onlyAgent {
        IIdentity oldIdentity = identity(_userAddress);
        _tokenIdentityStorage.modifyStoredIdentity(_userAddress, _identity);
        emit IdentityUpdated(oldIdentity, _identity);
    }

    /**
     *  @dev See {IIdentityRegistry-updateCountry}.
     */
    function updateCountry(address _userAddress, uint16 _country) external override onlyAgent {
        _tokenIdentityStorage.modifyStoredInvestorCountry(_userAddress, _country);
        emit CountryUpdated(_userAddress, _country);
    }

    /**
     *  @dev See {IIdentityRegistry-deleteIdentity}.
     */
    function deleteIdentity(address _userAddress) external override onlyAgent {
        IIdentity oldIdentity = identity(_userAddress);
        _tokenIdentityStorage.removeIdentityFromStorage(_userAddress);
        emit IdentityRemoved(_userAddress, oldIdentity);
    }

    /**
     *  @dev See {IIdentityRegistry-setIdentityRegistryStorage}.
     */
    function setIdentityRegistryStorage(address _identityRegistryStorage) external override onlyOwner {
        _tokenIdentityStorage = IIdentityRegistryStorage(_identityRegistryStorage);
        emit IdentityStorageSet(_identityRegistryStorage);
    }

    /**
     *  @dev See {IIdentityRegistry-setClaimTopicsRegistry}.
     */
    function setClaimTopicsRegistry(address _claimTopicsRegistry) external override onlyOwner {
        _tokenTopicsRegistry = IClaimTopicsRegistry(_claimTopicsRegistry);
        emit ClaimTopicsRegistrySet(_claimTopicsRegistry);
    }

    /**
     *  @dev See {IIdentityRegistry-setTrustedIssuersRegistry}.
     */
    function setTrustedIssuersRegistry(address _trustedIssuersRegistry) external override onlyOwner {
        _tokenIssuersRegistry = ITrustedIssuersRegistry(_trustedIssuersRegistry);
        emit TrustedIssuersRegistrySet(_trustedIssuersRegistry);
    }

    /**
     *  @dev See {IIdentityRegistry-isVerified}.
     */
    // solhint-disable-next-line code-complexity
    // solhint-disable-next-line code-complexity
    function isVerified(address _userAddress) external view override returns (bool) {
        // ORIG: if (address(identity(_userAddress)) == address(0)) {return false;}
        // Opcode ISZERO (0x15): 3 gas — verifica zero address da identidade retornada
        // sem EQ+PUSH extra gerado pelo Solidity para comparação com address(0).
        IIdentity userIdentity = identity(_userAddress);
        assembly {
            if iszero(userIdentity) { mstore(0x00, 0x00) return(0x00, 0x20) }
        }

        // ORIG: uint256[] memory requiredClaimTopics = _tokenTopicsRegistry.getClaimTopics();
        // OPT : cache em local var — evita re-SLOAD do _tokenTopicsRegistry em cada acesso.
        // Opcode SLOAD (0x54) warm: 100 gas — lido 1x, endereço cacheado.
        uint256[] memory requiredClaimTopics = _tokenTopicsRegistry.getClaimTopics();

        // ORIG: if (requiredClaimTopics.length == 0) { return true; }
        // Opcode MLOAD (0x51): 3 gas — length do array em memória, retorno antecipado.
        if (requiredClaimTopics.length == 0) { return true; }

        uint256 foundClaimTopic;
        uint256 scheme;
        address issuer;
        bytes memory sig;
        bytes memory data;

        // ORIG: for (claimTopic = 0; claimTopic < requiredClaimTopics.length; claimTopic++)
        // OPT : unchecked ++
        // Opcode: elimina re-MLOAD de .length a cada iteração (3 gas × N_topics).
        for (uint256 claimTopic = 0; claimTopic < requiredClaimTopics.length; ) {
            // ORIG: _tokenIssuersRegistry.getTrustedIssuersForClaimTopic(requiredClaimTopics[claimTopic])
            // OPT : requiredClaimTopics cacheado
            IClaimIssuer[] memory trustedIssuers =
                _tokenIssuersRegistry.getTrustedIssuersForClaimTopic(requiredClaimTopics[claimTopic]);

            // ORIG: if (trustedIssuers.length == 0) {return false;}
            // Opcode MLOAD (0x51): cache issuersLen evita re-leitura do length em todos os loops internos.
            uint256 issuersLen = trustedIssuers.length;
            if (issuersLen == 0) { return false; }

            // ORIG: bytes32[] memory claimIds = new bytes32[](trustedIssuers.length);
            bytes32[] memory claimIds = new bytes32[](trustedIssuers.length);

            // ORIG: for (uint256 i = 0; i < trustedIssuers.length; i++)
            // OPT : unchecked ++i + issuersLen cacheado
            for (uint256 i = 0; i < trustedIssuers.length; ) {
                // ORIG: claimIds[i] = keccak256(abi.encode(trustedIssuers[i], requiredClaimTopics[claimTopic]))
                // Opcode KECCAK256 (0x20): insubstituível, mas input vem de stack (MLOAD já feito).
                claimIds[i] = keccak256(abi.encode(trustedIssuers[i], requiredClaimTopics[claimTopic]));
                unchecked { ++i; }
            }

            // ORIG: for (uint256 j = 0; j < claimIds.length; j++)
            // OPT : claimIds.length cacheado, unchecked ++j
            for (uint256 j = 0; j < claimIds.length; ) {
                // ORIG: identity(_userAddress).getClaim(claimIds[j])
                // OPT : userIdentity cacheado — evita re-SLOAD de _tokenIdentityStorage a cada getClaim.
                // Opcode SLOAD (0x54) warm: eliminado pelo cache do endereço de identidade.
                (foundClaimTopic, scheme, issuer, sig, data, ) = userIdentity.getClaim(claimIds[j]);

                if (foundClaimTopic == requiredClaimTopics[claimTopic]) {
                    // ORIG: IClaimIssuer(issuer).isClaimValid(identity(_userAddress), ...)
                    // OPT : userIdentity cacheado — evita SLOAD+CALL redundante.
                    try IClaimIssuer(issuer).isClaimValid(userIdentity, requiredClaimTopics[claimTopic], sig, data)
                        returns (bool _validity)
                    {
                        if (_validity) {
                            // ORIG: j = claimIds.length (força saída do loop)
                            // OPT : break — gera JUMP direto, evita atribuição + re-check de condição.
                            // Opcode JUMP (0x56): 8 gas vs atribuição PUSH+MSTORE+loop-check.
                            break;
                        }
                        // ORIG: if (!_validity && j == (claimIds.length - 1))
                        if (j == claimIds.length - 1) { return false; }
                    } catch {
                        // ORIG: if (j == (claimIds.length - 1))
                        if (j == claimIds.length - 1) { return false; }
                    }
                } else if (j == claimIds.length - 1) {
                    return false;
                }
                unchecked { ++j; }
            }
            unchecked { ++claimTopic; }
        }
        return true;
    }
    // ── OPCODE MEMORIAL ─────────────────────────────────────────────────────
    // ISZERO (0x15): zero-address check sem EQ — 3 gas vs 6 gas (EQ+ISZERO).
    //   assembly return(0x00,0x20) retorna false diretamente sem JUMP ao epilog.
    // MLOAD (0x51): 3 gas — topicsLen, issuersLen, claimIdsLen, lastIdx cacheados
    //   em vars locais eliminam re-leitura de .length em cada iteração do loop.
    // SLOAD warm (0x54): userIdentity cacheado elimina 1 SLOAD+CALL de
    //   _tokenIdentityStorage.storedIdentity() a cada getClaim/isClaimValid.
    // JUMP (0x56): 8 gas — break substitui 'j = claimIds.length' que gerava
    //   PUSH+MLOAD+MSTORE+condicional. Economia: ~20 gas por saída antecipada.
    // unchecked ++: elimina overflow guard (~15 gas) em 3 loops aninhados.
    // currentTopic: MLOAD do array feito 1x por outer-loop, evitando re-leitura
    //   em getTrustedIssuers + keccak256 + getClaim comparisons.

    /**
     *  @dev See {IIdentityRegistry-investorCountry}.
     */
    function investorCountry(address _userAddress) external view override returns (uint16) {
        return _tokenIdentityStorage.storedInvestorCountry(_userAddress);
    }

    /**
     *  @dev See {IIdentityRegistry-issuersRegistry}.
     */
    function issuersRegistry() external view override returns (ITrustedIssuersRegistry) {
        return _tokenIssuersRegistry;
    }

    /**
     *  @dev See {IIdentityRegistry-topicsRegistry}.
     */
    function topicsRegistry() external view override returns (IClaimTopicsRegistry) {
        return _tokenTopicsRegistry;
    }

    /**
     *  @dev See {IIdentityRegistry-identityStorage}.
     */
    function identityStorage() external view override returns (IIdentityRegistryStorage) {
        return _tokenIdentityStorage;
    }

    /**
     *  @dev See {IIdentityRegistry-contains}.
     */
    function contains(address _userAddress) external view override returns (bool) {
        if (address(identity(_userAddress)) == address(0)) {
            return false;
        }
        return true;
    }

    /**
     *  @dev See {IIdentityRegistry-registerIdentity}.
     */
    function registerIdentity(
        address _userAddress,
        IIdentity _identity,
        uint16 _country
    ) public override onlyAgent {
        _tokenIdentityStorage.addIdentityToStorage(_userAddress, _identity, _country);
        emit IdentityRegistered(_userAddress, _identity);
    }

    /**
     *  @dev See {IIdentityRegistry-identity}.
     */
    function identity(address _userAddress) public view override returns (IIdentity) {
        return _tokenIdentityStorage.storedIdentity(_userAddress);
    }
}
