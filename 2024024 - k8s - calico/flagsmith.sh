#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

echo "Installing Flagsmith"
whoami
pwd

snap install yq 

helm repo add flagsmith https://flagsmith.github.io/flagsmith-charts/
helm repo update
helm install -n flagsmith --create-namespace flagsmith flagsmith/flagsmith

kubectl wait deployment -n flagsmith --all --for condition=Available=True --timeout=300s

fs_api_podname=$(kubectl get pods -n flagsmith -l "app.kubernetes.io/component=api,app.kubernetes.io/instance=flagsmith" -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it --tty=false --namespace=flagsmith -c flagsmith-api $fs_api_podname -- ash << EOF
export DJANGO_SUPERUSER_EMAIL='test@mail.com'
export DJANGO_SUPERUSER_USERNAME='test'
export DJANGO_SUPERUSER_PASSWORD='test'
export DJANGO_SUPERUSER_FIRST_NAME='test'
export DJANGO_SUPERUSER_LAST_NAME='test'
export DJANGO_SUPERUSER_SIGN_UP_TYPE='NO_INVITE'
python manage.py createsuperuser --noinput
EOF


# https://stackoverflow.com/questions/67415637/kubectl-port-forward-reliably-in-a-shell-script
flagsmith_localport=54320
kubectl port-forward -n flagsmith svc/flagsmith-frontend $flagsmith_localport:8080 > /dev/null 2>&1 &

kubeforward_pid=$!
# echo pid: $pid

# kill the port-forward regardless of how this script exits
trap '{
    echo killing $kubeforward_pid
    kill $kubeforward_pid 2>/dev/null
}' EXIT

# echo $kubeforward_pid

while ! nc -vz localhost $flagsmith_localport > /dev/null 2>&1 ; do
    # echo sleeping
    sleep 0.5
done

echo port available

fs_login=""""$(
curl http://localhost:$flagsmith_localport/api/v1/auth/login/ -s -X POST -H "Content-Type: application/json" -d @- << EOF
{
    "email":"test@mail.com", 
    "password":"test"
}
EOF
)""""

echo "auth status code $?"

if [ -z "$fs_login" ]; then
    echo "cannot retrieve login" 1>&2;
    exit 1
else
    echo "login '$fs_login'"
fi

fs_token=$(echo $fs_login | yq -r .key)
echo "login token '$fs_token'"

fs_organisation=""""$(
curl http://localhost:$flagsmith_localport/api/v1/organisations/ -s -X POST -H "Authorization: Token $fs_token" -H "Content-Type: application/json" -d @- << EOF
{
  "name":"organisation1"
}
EOF
)""""
echo "create organisation status code $?"
echo "organisation $fs_organisation"

fs_organisation_id=$(echo $fs_organisation | yq -r .id)
echo organisation id $fs_organisation_id

fs_project=""""$(curl http://localhost:$flagsmith_localport/api/v1/projects/ -s -X POST -H "Authorization: Token $fs_token" -H "Content-Type: application/json" -d @- << EOF
{
  "name":"project1", 
  "organisation":"$fs_organisation_id"
}
EOF
)""""

echo $fs_project
fs_project_id=$(echo $fs_project | yq -r .id)
echo project id $fs_project_id

fs_environment=""""$(curl http://localhost:$flagsmith_localport/api/v1/environments/ -s -X POST -H "Authorization: Token $fs_token" -H "Content-Type: application/json" -d @- << EOF
{
  "name":"dev", "project":"$fs_project_id"
}
EOF
)""""

echo $fs_environment
fs_environment_id=$(echo $fs_environment | yq -r .id)
echo environment id $fs_environment_id

kill -SIGINT $kubeforward_pid


# https://api.flagsmith.com/api/v1/docs/
# curl http://localhost:58989/api/v1/organisations/ -H "Authorization: Token 5861e0da1cf14764b6979c304780943125dcf620"
# curl http://localhost:58989/api/v1/organisations/ -X POST -H "Authorization: Token 5861e0da1cf14764b6979c304780943125dcf620" -H "Content-Type: application/json" -d "{""name"":""organisation1""}"
# curl http://localhost:58989/api/v1/projects/ -X POST -H "Authorization: Token 5861e0da1cf14764b6979c304780943125dcf620" -H "Content-Type: application/json" -d "{""name"":""project1"", ""organisation"":""1""}"
# curl http://localhost:58989/api/v1/environments/ -X POST -H "Authorization: Token 5861e0da1cf14764b6979c304780943125dcf620" -H "Content-Type: application/json" -d "{""name"":""dev"", ""project"":""2""}"
# curl http://localhost:58989/api/v1/projects/2/features/ -X POST -H "Authorization: Token 5861e0da1cf14764b6979c304780943125dcf620" -H "Content-Type: application/json" -d "{""name"":""feature1""}"
# curl http://localhost:58989/api/v1/projects/2/features/ -X GET -H "Authorization: Token 5861e0da1cf14764b6979c304780943125dcf620"

# curl http://localhost:58989/api/environments/CEHDjwK4k6WvzS8azZK7yz/featurestates/ -X GET -H "Authorization: Token 5861e0da1cf14764b6979c304780943125dcf620"

# curl http://localhost:58989/api/v1/projects/2/features/3/ -X PATCH -H "Authorization: Token 5861e0da1cf14764b6979c304780943125dcf620" -H "Content-Type: application/json" -d "{""feature_state_value"":""toto-patch""}"


# curl http://localhost:58989/api/v1/auth/users/ -X GET -H "Authorization: Token 5861e0da1cf14764b6979c304780943125dcf620"
# curl http://localhost:58989/api/v1/environments/ -X GET -H "Authorization: Token 5861e0da1cf14764b6979c304780943125dcf620"

# curl http://localhost:58989/api/v1/environments/ -H "Authorization: Token 5861e0da1cf14764b6979c304780943125dcf620" -H "content-type: application/json" -d "{""name"":""New Environment"",""project"":""1""}"


echo "Flagsmith installed"
