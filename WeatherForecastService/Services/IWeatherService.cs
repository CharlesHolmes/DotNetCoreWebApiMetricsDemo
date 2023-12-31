﻿using WeatherForecastService.Models;

namespace WeatherForecastService.Services
{
    public interface IWeatherService
    {
        Task<IEnumerable<WeatherForecast>> GetWeatherForecasts(bool includeRadar, bool includeSatellite);
    }
}
