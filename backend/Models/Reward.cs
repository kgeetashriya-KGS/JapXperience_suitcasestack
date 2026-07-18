namespace StackingGameBackend.Models
{
    public class Reward
    {
        public int Id { get; set; }

        public bool Success { get; set; }

        public string RewardName { get; set; } = "";

        public string Message { get; set; } = "";

        public bool Claimed { get; set; }

        public bool Expired { get; set; }

        public int Score { get; set; }
    }
}