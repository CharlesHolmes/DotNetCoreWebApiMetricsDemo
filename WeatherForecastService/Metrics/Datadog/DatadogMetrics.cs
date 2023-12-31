﻿using StatsdClient;
using System.Text;

namespace WeatherForecastService.Metrics.Datadog
{
    public sealed class DatadogMetrics : IDatadogMetrics, IDisposable
    {
        private readonly ILogger<DatadogMetrics> _logger;
        private readonly DogStatsdService _client;

        public DatadogMetrics(ILogger<DatadogMetrics> logger)
        {
            _logger = logger;
            _client = GetDatadogClient();
        }

        public void IncrementDatadogCounter(string name, Dictionary<string, string> tags)
        {
            string[] datadogTags = GetDatadogTags(tags);
            _client.Increment(Sterilize(name), tags: datadogTags);

        }

        public void SetDatadogHistogram(string name, double value, Dictionary<string, string> tags)
        {
            string[] datadogTags = GetDatadogTags(tags);
            _client.Histogram(Sterilize(name), value, tags: datadogTags);
        }

        public void Dispose()
        {
            _client?.Dispose();
        }

        private static string[] GetDatadogTags(Dictionary<string, string> tags)
        {
            return tags
                .Select(kvp => $"{Sterilize(kvp.Key)}:{kvp.Value}")
                .ToArray();
        }

        private static string Sterilize(string input)
        {
            var result = new StringBuilder();
            foreach (char c in input)
            {
                if (char.IsLetterOrDigit(c) || c == '.')
                {
                    result.Append(c);
                }
                else
                {
                    result.Append('_');
                }
            }

            return result.ToString().ToLower();
        }

        private DogStatsdService GetDatadogClient()
        {
            var client = new DogStatsdService();
            var config = new StatsdConfig
            {
                StatsdServerName = "127.0.0.1",
                StatsdPort = 8125
            };

            bool configured = client.Configure(config, (e) =>
            {
                _logger.LogCritical(e, "Cannot initialize dogstatsd.");
                throw new InvalidOperationException("Cannot initialize dogstatsd.", e);
            });

            if (configured)
            {
                return client;
            }
            else
            {
                throw new InvalidOperationException("Cannot initialize dogstatsd.");
            }
        }
    }
}
