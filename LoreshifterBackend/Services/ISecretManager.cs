namespace Loreshifter.Services;

public interface ISecretManager
{
    /// <summary>
    /// Gets a secret value by its name
    /// </summary>
    /// <param name="secretName">Name of the secret to retrieve</param>
    /// <param name="defaultValue">Default value to return if secret is not found</param>
    /// <returns>Secret value as string</returns>
    /// <exception cref="InvalidOperationException">Thrown when secret is not found and no default value is provided</exception>
    string GetSecret(string secretName, string? defaultValue = null);
}
