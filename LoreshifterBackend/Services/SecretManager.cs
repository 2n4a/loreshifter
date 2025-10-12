namespace Loreshifter.Services;

public class SecretManager : ISecretManager
{
    private const string DockerSecretsPath = "/run/secrets/";

    public string GetSecret(string secretName, string? defaultValue = null)
    {
        if (string.IsNullOrWhiteSpace(secretName))
        {
            throw new ArgumentException("Secret name cannot be null or whitespace.", nameof(secretName));
        }

        var secretFilePath = Path.Combine(DockerSecretsPath, secretName);
        if (File.Exists(secretFilePath))
        {
            try
            {
                var secretValue = File.ReadAllText(secretFilePath).Trim();
                return secretValue;
            }
            catch (Exception)
            {
                // Continue to try other sources
            }
        }

        var envVarName = secretName.Replace("-", "_").ToUpper();
        var envValue = Environment.GetEnvironmentVariable(envVarName);
        if (!string.IsNullOrEmpty(envValue))
        {
            return envValue;
        }

        if (defaultValue != null)
        {
            return defaultValue;
        }

        throw new InvalidOperationException(
            $"Secret '{secretName}' not found in Docker secrets or environment variables, and no default value was provided.");
    }
}