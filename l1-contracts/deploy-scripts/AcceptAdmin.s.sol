// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Script} from "forge-std/Script.sol";

import {Ownable2Step} from "@openzeppelin/contracts-v4/access/Ownable2Step.sol";
import {IZKChain} from "contracts/state-transition/chain-interfaces/IZKChain.sol";
import {IAdmin} from "contracts/state-transition/chain-interfaces/IAdmin.sol";
import {ChainAdmin} from "contracts/governance/ChainAdmin.sol";
import {AccessControlRestriction} from "contracts/governance/AccessControlRestriction.sol";
import {IChainAdmin} from "contracts/governance/IChainAdmin.sol";
import {Call} from "contracts/governance/Common.sol";
import {Utils} from "./Utils.sol";
import {IGovernance} from "contracts/governance/IGovernance.sol";
import {stdToml} from "forge-std/StdToml.sol";
import {Diamond} from "contracts/state-transition/libraries/Diamond.sol";


bytes32 constant SET_TOKEN_MULTIPLIER_SETTER_ROLE = keccak256("SET_TOKEN_MULTIPLIER_SETTER_ROLE");

contract AcceptAdmin is Script {
    using stdToml for string;

    struct Config {
        address admin;
        address governor;
    }

    Config internal config;

    function initConfig() public {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/script-config/config-accept-admin.toml");
        string memory toml = vm.readFile(path);
        config.admin = toml.readAddress("$.target_addr");
        config.governor = toml.readAddress("$.governor");
    }

    // This function should be called by the owner to accept the admin role
    function governanceAcceptOwner(address governor, address target) public {
        Ownable2Step adminContract = Ownable2Step(target);
        Utils.executeUpgrade({
            _governor: governor,
            _salt: bytes32(0),
            _target: target,
            _data: abi.encodeCall(adminContract.acceptOwnership, ()),
            _value: 0,
            _delay: 0
        });
    }

    // This function should be called by the owner to accept the admin role
    function governanceAcceptAdmin(address governor, address target) public {
        IZKChain adminContract = IZKChain(target);
        Utils.executeUpgrade({
            _governor: governor,
            _salt: bytes32(0),
            _target: target,
            _data: abi.encodeCall(adminContract.acceptAdmin, ()),
            _value: 0,
            _delay: 0
        });
    }

    // This function should be called by the owner to accept the admin role
    function chainAdminAcceptAdmin(ChainAdmin chainAdmin, address target) public {
        IZKChain adminContract = IZKChain(target);

        Call[] memory calls = new Call[](1);
        calls[0] = Call({target: target, value: 0, data: abi.encodeCall(adminContract.acceptAdmin, ())});

        vm.startBroadcast();
        chainAdmin.multicall(calls, true);
        vm.stopBroadcast();
    }

    // This function should be called by the owner to update token multiplier setter role
    function chainSetTokenMultiplierSetter(
        address accessControlRestriction,
        address diamondProxyAddress,
        address setter
    ) public {
        AccessControlRestriction restriction = AccessControlRestriction(accessControlRestriction);

        if (
            restriction.requiredRoles(diamondProxyAddress, IAdmin.setTokenMultiplier.selector) !=
            SET_TOKEN_MULTIPLIER_SETTER_ROLE
        ) {
            vm.startBroadcast();
            restriction.setRequiredRoleForCall(
                diamondProxyAddress,
                IAdmin.setTokenMultiplier.selector,
                SET_TOKEN_MULTIPLIER_SETTER_ROLE
            );
            vm.stopBroadcast();
        }

        if (!restriction.hasRole(SET_TOKEN_MULTIPLIER_SETTER_ROLE, setter)) {
            vm.startBroadcast();
            restriction.grantRole(SET_TOKEN_MULTIPLIER_SETTER_ROLE, setter);
            vm.stopBroadcast();
        }
    }

    function governanceExecuteCalls(
        bytes memory callsToExecute,
        address governanceAddr
    ) public {
        IGovernance governance = IGovernance(governanceAddr);
        Ownable2Step ownable = Ownable2Step(governanceAddr);

        Call[] memory calls = abi.decode(callsToExecute, (Call[]));

        IGovernance.Operation memory operation = IGovernance.Operation({
            calls: calls,
            predecessor: bytes32(0),
            salt: bytes32(0)
        });

        vm.startBroadcast(ownable.owner());
        governance.scheduleTransparent(operation, 0);
        // We assume that the total value is 0
        governance.execute{value: 0}(operation);
        vm.stopBroadcast();
    }

    function adminExecuteUpgrade(
        bytes memory diamondCut,
        address adminAddr,
        address accessControlRestriction,
        address chainDiamondProxy
    ) public {
        uint256 oldProtocolVersion = IZKChain(chainDiamondProxy).getProtocolVersion();
        Diamond.DiamondCutData memory upgradeCutData = abi.decode(diamondCut, (Diamond.DiamondCutData));

        Utils.adminExecute(
            adminAddr,
            accessControlRestriction,
            chainDiamondProxy,
            abi.encodeCall(IAdmin.upgradeChainFromVersion, (oldProtocolVersion, upgradeCutData)),
            0
        );
    }

    function setDAValidatorPair(
        ChainAdmin chainAdmin,
        address target,
        address l1DaValidator,
        address l2DaValidator
    ) public {
        IZKChain adminContract = IZKChain(target);

        Call[] memory calls = new Call[](1);
        calls[0] = Call({
            target: target,
            value: 0,
            data: abi.encodeCall(adminContract.setDAValidatorPair, (l1DaValidator, l2DaValidator))
        });

        vm.startBroadcast();
        chainAdmin.multicall(calls, true);
        vm.stopBroadcast();
    }
}
