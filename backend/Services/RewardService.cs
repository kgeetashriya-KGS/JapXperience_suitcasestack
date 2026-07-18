using StackingGameBackend.Models;

namespace StackingGameBackend.Services
{
    public class RewardService
    {
        // Thresholds and copy live ONLY here. Flutter never sees these.
        private const int CoffeeCouponScore = 100;
        private const int LoungeAccessScore = 200;
        private const int TravelVoucherScore = 300;

        private const string CoffeeCouponName = "Free Coffee Coupon";
        private const string LoungeAccessName = "Airport Lounge Access";
        private const string TravelVoucherName = "₹500 Travel Voucher";

        private Reward? currentReward;

        /// <summary>
        /// Computes and returns the reward for the given score. The
        /// computed result is also stored so ClaimReward()/ExpireReward()
        /// have something to act on afterward.
        /// </summary>
        public Reward GetReward(int score)
        {
            string rewardName = "";
            string message = "Better luck next time! No reward unlocked.";

            if (score >= TravelVoucherScore)
            {
                rewardName = TravelVoucherName;
            }
            else if (score >= LoungeAccessScore)
            {
                rewardName = LoungeAccessName;
            }
            else if (score >= CoffeeCouponScore)
            {
                rewardName = CoffeeCouponName;
            }

            bool success = rewardName != "";
            if (success)
            {
                message = $"Congratulations! You've unlocked {rewardName}.";
            }

            currentReward = new Reward
            {
                Id = score,
                Success = success,
                RewardName = rewardName,
                Message = message,
                Claimed = false,
                Expired = false,
                Score = score,
            };

            return currentReward;
        }

        public Reward? ClaimReward()
        {
            if (currentReward == null)
                return null;

            if (currentReward.Expired)
                return null;

            if (currentReward.Claimed)
                return currentReward;

            currentReward.Claimed = true;

            Reward claimedReward = currentReward;
            currentReward = null;

            return claimedReward;
        }

        public Reward? ExpireReward()
        {
            if (currentReward == null)
                return null;

            if (currentReward.Claimed)
                return null;

            if (currentReward.Expired)
                return currentReward;

            currentReward.Expired = true;

            Reward expiredReward = currentReward;
            currentReward = null;

            return expiredReward;
        }
    }
}