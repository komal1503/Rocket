//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/access/Ownable.sol';
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import 'base64-sol/base64.sol';

contract NFTG is ERC721URIStorage, Ownable {
  constructor() ERC721('NFT-Game', 'NFTG') Ownable() {}

    event requestedRandomSVG(bytes32 indexed requestId, uint256 indexed tokenId); 
    event CreatedUnfinishedRandomSVG(uint256 indexed tokenId, uint256 randomNumber);
    event CreatedRandomSVG(uint256 indexed tokenId, string tokenURI);
    mapping(bytes32 => address) public requestIdToSender;
    mapping(bytes32 => uint256) public requestIdToTokenId;
    mapping(uint256 => uint256) public tokenIdToRandomNumber;

    uint256 public tokenCounter;
    bytes32 internal keyHash;
    uint256 internal fee;
    uint256 public price;

    // SVG Parameters
    uint256 public maxNumberOfPaths;
    uint256 public maxNumberOfPathCommands;
    uint256 public size;
    string[] public pathCommands;
    string[] public colors;

    constructor(address _VRFCoordinator, address _LinkToken, bytes32 _keyhash, uint256 _fee) 
    VRFConsumerBase(_VRFCoordinator, _LinkToken)
    ERC721("RandomSVG", "rsNFT")
    {
        tokenCounter = 0;
        price = 10000000000000000; // 0.01 ETH / MATIC / AVAX 
        keyHash = _keyhash;
        fee = _fee;
        maxNumberOfPaths = 10;
        maxNumberOfPathCommands = 5;
        size = 500;
        pathCommands = ["M", "L"];
        colors = ["red", "blue", "green", "yellow", "black", "white"];
    }

    function withdraw() public payable onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    function create() public payable returns (bytes32 requestId) {
        require(msg.value >= price, "Need to send more ETH!");
        requestId = requestRandomness(keyHash, fee);
        requestIdToSender[requestId] = msg.sender;
        uint256 tokenId = tokenCounter; 
        requestIdToTokenId[requestId] = tokenId;
        tokenCounter = tokenCounter + 1;
        emit requestedRandomSVG(requestId, tokenId);

    }

    function fulfillRandomness(bytes32 _requestId, uint256 _randomNumber) internal override {
        address nftOwner = requestIdToSender[_requestId];
        uint256 tokenId = requestIdToTokenId[_requestId];
        _safeMint(nftOwner, tokenId);
        tokenIdToRandomNumber[tokenId] = _randomNumber;
        emit CreatedUnfinishedRandomSVG(tokenId, _randomNumber);
    }

    function finishMint(uint256 _tokenId) public {
        require(bytes(tokenURI(_tokenId)).length <= 0, "tokenURI is already set!"); 
        require(tokenCounter > _tokenId, "TokenId has not been minted yet!");
        require(tokenIdToRandomNumber[_tokenId] > 0, "Need to wait for the Chainlink node to respond!");
        uint256 randomNumber = tokenIdToRandomNumber[_tokenId];
        string memory svg = generateSVG(randomNumber);
        string memory imageURI = svgToImageURI(svg);
        string memory tokenURI = formatTokenURI(imageURI);
        _setTokenURI(_tokenId, tokenURI);
        emit CreatedRandomSVG(_tokenId, svg);
    }

    function generateSVG(uint256 _randomness) public view returns (string memory finalSvg) {
        // We will only use the path element, with stroke and d elements
        uint256 numberOfPaths = (_randomness % maxNumberOfPaths) + 1;
        finalSvg = string(abi.encodePacked("<svg xmlns='http://www.w3.org/2000/svg' height='", uint2str(size), "' width='", uint2str(size), "'>"));
        for(uint i = 0; i < numberOfPaths; i++) {
            // we get a new random number for each path
            string memory pathSvg = generatePath(uint256(keccak256(abi.encode(_randomness, i))));
            finalSvg = string(abi.encodePacked(finalSvg, pathSvg));
        }
        finalSvg = string(abi.encodePacked(finalSvg, "</svg>"));
    }

    function generatePath(uint256 _randomness) public view returns(string memory pathSvg) {
        uint256 numberOfPathCommands = (_randomness % maxNumberOfPathCommands) + 1;
        pathSvg = "<path d='";
        for(uint i = 0; i < numberOfPathCommands; i++) {
            string memory pathCommand = generatePathCommand(uint256(keccak256(abi.encode(_randomness, size + i))));
            pathSvg = string(abi.encodePacked(pathSvg, pathCommand));
        }
        string memory color = colors[_randomness % colors.length];
        pathSvg = string(abi.encodePacked(pathSvg, "' fill='transparent' stroke='", color,"'/>"));
    }

    function generatePathCommand(uint256 _randomness) public view returns(string memory pathCommand) {
        pathCommand = pathCommands[_randomness % pathCommands.length];
        uint256 parameterOne = uint256(keccak256(abi.encode(_randomness, size * 2))) % size;
        uint256 parameterTwo = uint256(keccak256(abi.encode(_randomness, size * 2 + 1))) % size;
        pathCommand = string(abi.encodePacked(pathCommand, " ", uint2str(parameterOne), " ", uint2str(parameterTwo)));
    }

    function generatePath(uint256 _randomness) public view returns(string memory pathSvg) {
        uint256 numberOfPathCommands = (_randomness % maxNumberOfPathCommands) + 1;
        pathSvg = "<path d='";
        for(uint i = 0; i < numberOfPathCommands; i++) {
            string memory pathCommand = generatePathCommand(uint256(keccak256(abi.encode(_randomness, size + i))));
            pathSvg = string(abi.encodePacked(pathSvg, pathCommand));
        }
        string memory color = colors[_randomness % colors.length];
        pathSvg = string(abi.encodePacked(pathSvg, "' fill='transparent' stroke='", color,"'/>"));
    }

    function generatePathCommand(uint256 _randomness) public view returns(string memory pathCommand) {
        pathCommand = pathCommands[_randomness % pathCommands.length];
        uint256 parameterOne = uint256(keccak256(abi.encode(_randomness, size * 2))) % size;
        uint256 parameterTwo = uint256(keccak256(abi.encode(_randomness, size * 2 + 1))) % size;
        pathCommand = string(abi.encodePacked(pathCommand, " ", uint2str(parameterOne), " ", uint2str(parameterTwo)));
    }

    function svgToImageURI(string memory _svg) public pure returns (string memory) {
      string memory baseURL = "data:image/svg+xml;base64,";
       string memory svgBase64Encoded = Base64.encode(bytes(string(abi.encodePacked(_svg))));
       return string(abi.encodePacked(baseURL,svgBase64Encoded));
    }

  function formatTokenURI(string memory _imageURI) public pure returns (string memory) {
      return string(
              abi.encodePacked(
                  "data:application/json;base64,",
                  Base64.encode(
                      bytes(
                          abi.encodePacked(
                              '{"name":"',
                              "NFT Game", // You can add whatever name here
                              '", "description":"An dynamic NFT game which is purely on-chain", "attributes":"", "image":"',_imageURI,'"}'
                          )
                      )
                  )
              )
          );
  }

// From: https://stackoverflow.com/a/65707309/11969592
  function uint2str(uint _i) internal pure returns (string memory _uintAsString) {
      if (_i == 0) {
          return "0";
      }
      uint j = _i;
      uint len;
      while (j != 0) {
          len++;
          j /= 10;
      }
      bytes memory bstr = new bytes(len);
      uint k = len;
      while (_i != 0) {
          k = k-1;
          uint8 temp = (48 + uint8(_i - _i / 10 * 10));
          bytes1 b1 = bytes1(temp);
          bstr[k] = b1;
          _i /= 10;
      }
      return string(bstr);
  }

}