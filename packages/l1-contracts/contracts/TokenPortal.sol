pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Messaging
import {IRegistry} from "@aztec/l1-contracts/src/core/interfaces/messagebridge/IRegistry.sol";
import {IInbox} from "@aztec/l1-contracts/src/core/interfaces/messagebridge/IInbox.sol";
import {DataStructures} from "@aztec/l1-contracts/src/core/libraries/DataStructures.sol";
import {Hash} from "@aztec/l1-contracts/src/core/libraries/Hash.sol";

contract TokenPortal {
    using SafeERC20 for IERC20;

    IRegistry public registry;
    IERC20 public underlying;
    bytes32 public l2TokenAddress;

    function initialize(address _registry, address _underlying, bytes32 _l2TokenAddress) external {
        registry = IRegistry(_registry);
        underlying = IERC20(_underlying);
        l2TokenAddress = _l2TokenAddress;
    }

    /**
     * @notice Deposit funds into the portal and adds an L2 message which can only be consumed publicly on Aztec
     * @param _to - The aztec address of the recipient
     * @param _amount - The amount to deposit
     * @param _canceller - The address that can cancel the L1 to L2 message
     * @param _deadline - The timestamp after which the entry can be cancelled
     * @param _secretHash - The hash of the secret consumable message. The hash should be 254 bits (so it can fit in a Field element)
     * @return The key of the entry in the Inbox
     */
    function depositToAztecPublic(
        bytes32 _to,
        uint256 _amount,
        address _canceller,
        uint32 _deadline,
        bytes32 _secretHash
    ) external payable returns (bytes32) {
        // Preamble
        IInbox inbox = registry.getInbox();
        DataStructures.L2Actor memory actor = DataStructures.L2Actor(l2TokenAddress, 1);

        // Hash the message content to be reconstructed in the receiving contract
        bytes32 contentHash = Hash.sha256ToField(
            abi.encodeWithSignature("mint_public(bytes32,uint256,address)", _to, _amount, _canceller)
        );

        // Hold the tokens in the portal
        underlying.safeTransferFrom(msg.sender, address(this), _amount);

        // Send message to rollup
        return inbox.sendL2Message{value: msg.value}(actor, _deadline, contentHash, _secretHash);
    }

    /**
     * @notice Deposit funds into the portal and adds an L2 message which can only be consumed privately on Aztec
     * @param _secretHashForRedeemingMintedNotes - The hash of the secret to redeem minted notes privately on Aztec. The hash should be 254 bits (so it can fit in a Field element)
     * @param _amount - The amount to deposit
     * @param _canceller - The address that can cancel the L1 to L2 message
     * @param _deadline - The timestamp after which the entry can be cancelled
     * @param _secretHashForL2MessageConsumption - The hash of the secret consumable L1 to L2 message. The hash should be 254 bits (so it can fit in a Field element)
     * @return The key of the entry in the Inbox
     */
    function depositToAztecPrivate(
        bytes32 _secretHashForRedeemingMintedNotes,
        uint256 _amount,
        address _canceller,
        uint32 _deadline,
        bytes32 _secretHashForL2MessageConsumption
    ) external payable returns (bytes32) {
        // Preamble
        IInbox inbox = registry.getInbox();
        DataStructures.L2Actor memory actor = DataStructures.L2Actor(l2TokenAddress, 1);

        // Hash the message content to be reconstructed in the receiving contract
        bytes32 contentHash = Hash.sha256ToField(
            abi.encodeWithSignature(
                "mint_private(bytes32,uint256,address)", _secretHashForRedeemingMintedNotes, _amount, _canceller
            )
        );

        // Hold the tokens in the portal
        underlying.safeTransferFrom(msg.sender, address(this), _amount);

        // Send message to rollup
        return inbox.sendL2Message{value: msg.value}(actor, _deadline, contentHash, _secretHashForL2MessageConsumption);
    }
}
