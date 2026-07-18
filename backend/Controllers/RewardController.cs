using Microsoft.AspNetCore.Mvc;
using StackingGameBackend.Models;
using StackingGameBackend.Services;

namespace StackingGameBackend.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class RewardController : ControllerBase
        
    {
        private readonly RewardService _rewardService;
        public RewardController(RewardService rewardService)
        {
            _rewardService = rewardService;
        }
        [HttpPost("reward")]
        public IActionResult GetReward([FromBody] ScoreRequest request)
        {
            Reward reward = _rewardService.GetReward(request.Score);

            return Ok(reward);
        }
        [HttpPost("claim")]
        public IActionResult ClaimReward()
        {
            Reward? reward = _rewardService.ClaimReward();

            if (reward == null)
                return NotFound("No reward has been assigned.");

            return Ok(reward);
        }
        [HttpPost("expire")]
        public IActionResult ExpireReward()
        {
            Reward? reward = _rewardService.ExpireReward();

            if (reward == null)
                return NotFound("No reward has been assigned.");

            return Ok(reward);
        }
    }
}