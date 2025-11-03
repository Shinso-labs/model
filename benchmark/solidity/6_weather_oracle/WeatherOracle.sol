// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/// @title WeatherOracle
/// @notice Registry of city weather data with admin-gated writes and public reads.
/// @dev Mirrors Sui Move weather_oracle::weather semantics using OZ AccessControl + an ERC-721 snapshot NFT.
contract WeatherOracle is AccessControl {
    bytes32 public constant ADMIN_ROLE = DEFAULT_ADMIN_ROLE;

    // ---- Oracle metadata (Move: WeatherOracle { address, name, description }) ----
    address public oracleAddress;
    string  public name_;
    string  public description_;

    // ---- City record ----
    struct CityWeather {
        uint32 geonameId;
        string name;
        string country;
        uint32 latitude;            // degrees (scaled exactly as provided upstream)
        bool   positiveLatitude;    // N=true, S=false
        uint32 longitude;           // degrees
        bool   positiveLongitude;   // E=true, W=false
        uint16 weatherId;           // condition code
        uint32 temp;                // Kelvin
        uint32 pressure;            // hPa
        uint8  humidity;            // %
        uint16 visibility;          // meters
        uint16 windSpeed;           // m/s
        uint16 windDeg;             // degrees
        bool   hasWindGust;         // Option<u16> emulation
        uint16 windGust;            // m/s (valid iff hasWindGust)
        uint8  clouds;              // %
        uint32 dt;                  // epoch seconds
        bool   exists;              // registry sentinel
    }

    mapping(uint32 => CityWeather) private _cities;

    // ---- Events ----
    event OracleInitialized(address indexed admin, address indexed oracleAddress, string name, string description);
    event CityAdded(uint32 indexed geonameId, string name, string country);
    event CityRemoved(uint32 indexed geonameId);
    event CityUpdated(
        uint32 indexed geonameId,
        uint16 weatherId,
        uint32 temp,
        uint32 pressure,
        uint8  humidity,
        uint16 visibility,
        uint16 windSpeed,
        uint16 windDeg,
        bool   hasWindGust,
        uint16 windGust,
        uint8  clouds,
        uint32 dt
    );

    // ---- Snapshot NFT ----
    WeatherNFT public immutable snapshotNFT;

    constructor(
        string memory oracleName,
        string memory oracleDescription
    ) {
        _grantRole(ADMIN_ROLE, msg.sender);
        oracleAddress = msg.sender;
        name_ = oracleName;
        description_ = oracleDescription;

        snapshotNFT = new WeatherNFT(address(this));
        emit OracleInitialized(msg.sender, oracleAddress, oracleName, oracleDescription);
    }

    // ---------------- Admin (Move: requires AdminCap) ----------------

    /// @notice Add a new city to the oracle (idempotent on fresh ids).
    function addCity(
        uint32 geonameId,
        string calldata cityName,
        string calldata country,
        uint32 latitude,
        bool   positiveLatitude,
        uint32 longitude,
        bool   positiveLongitude
    ) external onlyRole(ADMIN_ROLE) {
        require(!_cities[geonameId].exists, "City already exists");

        CityWeather storage c = _cities[geonameId];
        c.geonameId = geonameId;
        c.name = cityName;
        c.country = country;
        c.latitude = latitude;
        c.positiveLatitude = positiveLatitude;
        c.longitude = longitude;
        c.positiveLongitude = positiveLongitude;
        // init measured fields to zero/none
        c.weatherId = 0;
        c.temp = 0;
        c.pressure = 0;
        c.humidity = 0;
        c.visibility = 0;
        c.windSpeed = 0;
        c.windDeg = 0;
        c.hasWindGust = false;
        c.windGust = 0;
        c.clouds = 0;
        c.dt = 0;
        c.exists = true;

        emit CityAdded(geonameId, cityName, country);
    }

    /// @notice Remove a city from the oracle.
    function removeCity(uint32 geonameId) external onlyRole(ADMIN_ROLE) {
        require(_cities[geonameId].exists, "City not found");
        delete _cities[geonameId];
        emit CityRemoved(geonameId);
    }

    /// @notice Update weather measurements for a city.
    function updateCity(
        uint32 geonameId,
        uint16 weatherId,
        uint32 temp,
        uint32 pressure,
        uint8  humidity,
        uint16 visibility,
        uint16 windSpeed,
        uint16 windDeg,
        bool   hasWindGust,
        uint16 windGust,
        uint8  clouds,
        uint32 dt
    ) external onlyRole(ADMIN_ROLE) {
        CityWeather storage c = _requireCity(geonameId);
        c.weatherId = weatherId;
        c.temp = temp;
        c.pressure = pressure;
        c.humidity = humidity;
        c.visibility = visibility;
        c.windSpeed = windSpeed;
        c.windDeg = windDeg;
        c.hasWindGust = hasWindGust;
        c.windGust = hasWindGust ? windGust : 0;
        c.clouds = clouds;
        c.dt = dt;

        emit CityUpdated(
            geonameId, weatherId, temp, pressure, humidity,
            visibility, windSpeed, windDeg, hasWindGust, c.windGust, clouds, dt
        );
    }

    // ---------------- Read-only (mirrors Move getters) ----------------

    function cityExists(uint32 geonameId) external view returns (bool) { return _cities[geonameId].exists; }
    function cityName(uint32 geonameId) external view returns (string memory) { return _requireCity(geonameId).name; }
    function cityCountry(uint32 geonameId) external view returns (string memory) { return _requireCity(geonameId).country; }
    function cityLatitude(uint32 geonameId) external view returns (uint32) { return _requireCity(geonameId).latitude; }
    function cityPositiveLatitude(uint32 geonameId) external view returns (bool) { return _requireCity(geonameId).positiveLatitude; }
    function cityLongitude(uint32 geonameId) external view returns (uint32) { return _requireCity(geonameId).longitude; }
    function cityPositiveLongitude(uint32 geonameId) external view returns (bool) { return _requireCity(geonameId).positiveLongitude; }
    function cityWeatherId(uint32 geonameId) external view returns (uint16) { return _requireCity(geonameId).weatherId; }
    function cityTemp(uint32 geonameId) external view returns (uint32) { return _requireCity(geonameId).temp; }
    function cityPressure(uint32 geonameId) external view returns (uint32) { return _requireCity(geonameId).pressure; }
    function cityHumidity(uint32 geonameId) external view returns (uint8) { return _requireCity(geonameId).humidity; }
    function cityVisibility(uint32 geonameId) external view returns (uint16) { return _requireCity(geonameId).visibility; }
    function cityWindSpeed(uint32 geonameId) external view returns (uint16) { return _requireCity(geonameId).windSpeed; }
    function cityWindDeg(uint32 geonameId) external view returns (uint16) { return _requireCity(geonameId).windDeg; }
    function cityHasWindGust(uint32 geonameId) external view returns (bool) { return _requireCity(geonameId).hasWindGust; }
    function cityWindGust(uint32 geonameId) external view returns (uint16) { return _requireCity(geonameId).windGust; }
    function cityClouds(uint32 geonameId) external view returns (uint8) { return _requireCity(geonameId).clouds; }
    function cityDt(uint32 geonameId) external view returns (uint32) { return _requireCity(geonameId).dt; }

    // ---------------- Snapshot NFT mint (Move: mint(oracle, geoname_id)) ----------------

    /// @notice Mint an ERC-721 snapshot of the current city weather to the caller.
    /// @dev Equivalent to returning a `WeatherNFT` object with the snapshot fields set.
    function mintSnapshot(uint32 geonameId) external returns (uint256 tokenId) {
        CityWeather memory c = _requireCity(geonameId);
        tokenId = snapshotNFT.mintSnapshot(
            msg.sender,
            c.geonameId,
            c.name,
            c.country,
            c.latitude,
            c.positiveLatitude,
            c.longitude,
            c.positiveLongitude,
            c.weatherId,
            c.temp,
            c.pressure,
            c.humidity,
            c.visibility,
            c.windSpeed,
            c.windDeg,
            c.hasWindGust,
            c.windGust,
            c.clouds,
            c.dt
        );
    }

    // ---- internal ----
    function _requireCity(uint32 geonameId) internal view returns (CityWeather storage c) {
        c = _cities[geonameId];
        require(c.exists, "City not found");
    }
}

/// @title WeatherNFT
/// @notice ERC-721 token whose metadata payload is an on-chain snapshot of weather data.
/// @dev Only the WeatherOracle (set at construction) can mint.
contract WeatherNFT is ERC721 {
    using Counters for Counters.Counter;

    address public immutable oracle;
    Counters.Counter private _ids;

    struct Snapshot {
        uint32 geonameId;
        string name;
        string country;
        uint32 latitude;
        bool   positiveLatitude;
        uint32 longitude;
        bool   positiveLongitude;
        uint16 weatherId;
        uint32 temp;
        uint32 pressure;
        uint8  humidity;
        uint16 visibility;
        uint16 windSpeed;
        uint16 windDeg;
        bool   hasWindGust;
        uint16 windGust;
        uint8  clouds;
        uint32 dt;
    }

    mapping(uint256 => Snapshot) private _snapshots;

    modifier onlyOracle() {
        require(msg.sender == oracle, "Not oracle");
        _;
    }

    event SnapshotMinted(uint256 indexed tokenId, uint32 indexed geonameId);

    constructor(address oracle_) ERC721("Weather Snapshot", "WXSNAP") {
        oracle = oracle_;
    }

    function mintSnapshot(
        address to,
        uint32 geonameId,
        string calldata name_,
        string calldata country,
        uint32 latitude,
        bool   positiveLatitude,
        uint32 longitude,
        bool   positiveLongitude,
        uint16 weatherId,
        uint32 temp,
        uint32 pressure,
        uint8  humidity,
        uint16 visibility,
        uint16 windSpeed,
        uint16 windDeg,
        bool   hasWindGust,
        uint16 windGust,
        uint8  clouds,
        uint32 dt
    ) external onlyOracle returns (uint256 tokenId) {
        tokenId = _ids.current();
        _ids.increment();

        _safeMint(to, tokenId);
        _snapshots[tokenId] = Snapshot({
            geonameId: geonameId,
            name: name_,
            country: country,
            latitude: latitude,
            positiveLatitude: positiveLatitude,
            longitude: longitude,
            positiveLongitude: positiveLongitude,
            weatherId: weatherId,
            temp: temp,
            pressure: pressure,
            humidity: humidity,
            visibility: visibility,
            windSpeed: windSpeed,
            windDeg: windDeg,
            hasWindGust: hasWindGust,
            windGust: hasWindGust ? windGust : 0,
            clouds: clouds,
            dt: dt
        });

        emit SnapshotMinted(tokenId, geonameId);
    }

    // Simple getters (on-chain consumers can read struct fields)
    function getSnapshot(uint256 tokenId) external view returns (Snapshot memory) {
        require(_exists(tokenId), "Nonexistent token");
        return _snapshots[tokenId];
    }
}