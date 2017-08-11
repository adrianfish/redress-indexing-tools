#!/bin/bash

dropdb REDRESS
createdb -E UNICODE -O redressadmin REDRESS
createlang plpgsql REDRESS
psql -U redressadmin -f redress.sql REDRESS
