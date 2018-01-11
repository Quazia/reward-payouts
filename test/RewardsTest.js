let chai = require("chai")
let chaiAsPromised = require("chai-as-promised")
chai.use(chaiAsPromised)
chai.should()

let Rewards = artifacts.require("Rewards")

contract("Rewards", (accounts) =>{
    let rewards

    before(async() => {
        rewards = await Rewards.new.apply(
            this
        )
    })

    it("should let the rewards be distributed", async() =>{

    })
})