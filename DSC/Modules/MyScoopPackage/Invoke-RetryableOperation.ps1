function Invoke-RetryableOperation
{
    param (
        [scriptblock]$Operation,
        [int]$MaxRetries = 2,
        [int]$RetryDelay = 2
    )

    $retryCount = 0
    do
    {
        try
        {
            return & $Operation
        }
        catch
        {
            $retryCount++
            if ($retryCount -ge $MaxRetries)
            {
                throw
            }
            Start-Sleep -Seconds $RetryDelay
        }
    } while ($retryCount -lt $MaxRetries)
}
