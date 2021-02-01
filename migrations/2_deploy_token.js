const RIEToken = artifacts.require("RIEToken");

module.exports = function (deployer) {
    const _owner = '0x88CC644C16A45ded69946882324110CFf465A49A';

  deployer.deploy(RIEToken, _owner);
};
